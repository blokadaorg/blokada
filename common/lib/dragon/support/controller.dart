import 'package:common/common/api/api.dart';
import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/support/api.dart';
import 'package:common/dragon/support/chat_history.dart';
import 'package:common/dragon/support/current_session.dart';
import 'package:common/dragon/support/support_unread.dart';
import 'package:common/platform/command/command.dart';
import 'package:dartx/dartx.dart';
import 'package:i18n_extension/i18n_extension.dart';

const _keyExpireSession = "supportExpireSession";

class SupportController with Logging {
  late final _api = dep<SupportApi>();
  late final _command = dep<CommandStore>();
  late final _currentSession = dep<CurrentSession>();
  late final _chatHistory = dep<ChatHistory>();
  late final _unread = dep<SupportUnreadController>();
  late final _scheduler = dep<Scheduler>();
  late String language = I18n.localeStr;

  bool initialized = false;
  late int _ttl;

  List<SupportMessage> messages = [];

  Function onChange = () {};
  Function onReset = () {};

  // Return true if session was just created
  Future<bool> loadOrInit(Marker m, {SupportEvent? event}) async {
    if (initialized) return false;
    initialized = true;

    await _currentSession.fetch();

    if (_currentSession.now != null) {
      try {
        final session = await _api.getSession(m, _currentSession.now!);
        _ttl = session.ttl;
        if (_ttl < 0) throw Exception("Session expired");
        await _loadChatHistory(session.history);
        return false;
      } catch (e, s) {
        log(m).e(msg: "Error loading session", err: e, stack: s);
        await startSession(m, event: event);
        return true;
      }
    } else {
      await startSession(m, event: event);
      return true;
    }
  }

  maybeStartSession(Marker m) async {
    if (_currentSession.now == null) {
      await startSession(m);
    }
  }

  _loadChatHistory(List<JsonSupportHistoryItem> history) async {
    await _chatHistory.fetch();
    messages = _chatHistory.now?.messages ?? [];

    final apiHistory = history.filter((e) => e.text?.isBlank == false).map((e) {
      return SupportMessage(e.text!, DateTime.parse(e.timestamp),
          isMe: !e.isAgent);
    }).toList();

    // Put the api history with respect to timestamps, and avoid duplicates
    for (final msg in apiHistory) {
      if (messages.any((e) => e.when == msg.when)) {
        continue;
      }
      messages.add(msg);
    }
    messages.sort((a, b) => a.when.compareTo(b.when));

    // Drop two exact same messages in a row
    // TODO: would be better with messages ids or something
    for (var i = 0; i < messages.length - 1; i++) {
      if (messages[i].text == messages[i + 1].text) {
        messages.removeAt(i + 1);
        i--;
      }
    }

    // Update local cache
    _chatHistory.now = SupportMessages(messages);

    onChange();
  }

  startSession(Marker m, {SupportEvent? event}) async {
    await loadOrInit(m, event: event);
    clearSession();
    final session = await _api.createSession(m, language, event: event);
    _currentSession.now = session.sessionId;
    _ttl = session.ttl;
    await _updateSessionExpiry();
    await _handleResponse(m, session.history);
  }

  clearSession() async {
    _currentSession.now = null;
    _chatHistory.now = null;
    messages = [];
    onChange();
    onReset();
  }

  sendMessage(String? message, Marker m, {bool retrying = false}) async {
    await loadOrInit(m);
    if (message?.startsWith("cc ") ?? false) {
      await _addMyMessage(message!);
      await _handleCommand(message.substring(3), m);
      return;
    }

    try {
      if (_currentSession.now == null) {
        await startSession(m);
      }

      if (message != null) {
        _addMyMessage(message);
        final msg = await _api.sendMessage(m, _currentSession.now!, message);
        if (msg.messages != null) await _handleResponse(m, msg.messages!);
      }
    } on HttpCodeException catch (e) {
      if (e.code >= 400 && e.code < 500) {
        // Session bad or expired
        clearSession();
        if (!retrying) {
          log(m).w("Invalid session, Retrying...");
          await sendMessage(message, m, retrying: true);
        } else {
          throw Exception("Retry failed: $e");
        }
      } else {
        throw Exception("Http error: $e");
      }
    } catch (e, s) {
      log(m).e(msg: "Error sending chat message", err: e, stack: s);
      await sleepAsync(const Duration(milliseconds: 500));
      await _addErrorMessage(m);
    }
    await _updateSessionExpiry();
  }

  sendEvent(SupportEvent event, Marker m, {bool retrying = false}) async {
    final sessionJustStarted = await loadOrInit(m, event: event);
    try {
      if (_currentSession.now == null) {
        await startSession(m, event: event);
      } else if (!sessionJustStarted) {
        final msg = await _api.sendEvent(m, _currentSession.now!, event);
        if (msg.messages != null) await _handleResponse(m, msg.messages!);
      }
    } on HttpCodeException catch (e) {
      if (e.code >= 400 && e.code < 500) {
        // Session bad or expired
        clearSession();
        if (!retrying) {
          log(m).w("Invalid session, Retrying...");
          await sendEvent(event, m, retrying: true);
        } else {
          throw Exception("Retry failed: $e");
        }
      } else {
        throw Exception("Http error: $e");
      }
    } catch (e, s) {
      log(m).e(msg: "Error sending chat event", err: e, stack: s);
    }
    await _updateSessionExpiry();
  }

  _addMyMessage(String msg) {
    final message = SupportMessage(msg, DateTime.now(), isMe: true);
    messages.add(message);
    _chatHistory.now = SupportMessages(messages);
    onChange();
  }

  _handleResponse(Marker m, List<JsonSupportHistoryItem> messages) async {
    for (final msg in messages) {
      if (msg.text == null || msg.text!.isBlank) {
        continue; // TODO: support other types of msgs
      }

      final message = SupportMessage(
        msg.text!,
        DateTime.parse(msg.timestamp),
        isMe: !msg.isAgent,
      );
      await _addMessage(m, message);
    }
  }

  _addMessage(m, SupportMessage message) async {
    messages.add(message);
    messages.sort((a, b) => a.when.compareTo(b.when));
    _chatHistory.now = SupportMessages(messages);
    onChange();
    await _unread.newMessage(m, message.text);
  }

  _addErrorMessage(Marker m, {String? error}) async {
    final message = SupportMessage(
      error ?? "Sorry did not understand, can you repeat?", // TODO: localize
      DateTime.now(),
      isMe: false,
    );
    await _addMessage(m, message);
  }

  _handleCommand(String message, Marker m) async {
    await log(m).trace("supportCommand", (m) async {
      try {
        await _command.onCommandString(message, m);
        final msg = SupportMessage("OK", DateTime.now(), isMe: false);
        await _addMessage(m, msg);
      } catch (e) {
        await sleepAsync(const Duration(milliseconds: 500));
        await _addErrorMessage(m, error: e.toString());
        rethrow;
      }
    });
  }

  _updateSessionExpiry() async {
    await _scheduler.addOrUpdate(Job(
      _keyExpireSession,
      Markers.support,
      before: DateTime.now().add(Duration(seconds: _ttl)),
      callback: (m) async {
        clearSession();
        return false; // No reschedule
      },
    ));
  }
}
