import 'package:common/command/command.dart';
import 'package:common/common/model.dart';
import 'package:common/dragon/scheduler.dart';
import 'package:common/dragon/support/api.dart';
import 'package:common/dragon/support/chat_history.dart';
import 'package:common/dragon/support/current_session.dart';
import 'package:common/dragon/support/support_unread.dart';
import 'package:common/notification/notification.dart';
import 'package:common/util/async.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';

const _keyExpireSession = "supportExpireSession";

class SupportController with TraceOrigin {
  late final _api = dep<SupportApi>();
  late final _command = dep<CommandStore>();
  late final _notification = dep<NotificationStore>();
  late final _currentSession = dep<CurrentSession>();
  late final _chatHistory = dep<ChatHistory>();
  late final _unread = dep<SupportUnread>();
  late final _scheduler = dep<Scheduler>();

  late int _ttl;
  String language = "en";

  List<SupportMessage> messages = [];

  Function onChange = () {};

  loadOrInit() async {
    await _currentSession.fetch();
    await _unread.fetch();

    // TODO: figure out language

    await _chatHistory.fetch();
    if (_chatHistory.now != null) {
      messages = _chatHistory.now!.messages;
      onChange();
    } else {
      _currentSession.now = null;
      sendMessage(null);
    }

    _unread.now = false;
  }

  startSession() async {
    clearSession();
    final session = await _api.createSession(language);
    _currentSession.now = session.sessionId;
    _ttl = session.ttl;
    _updateSessionExpiry();
    final hi =
        await _api.sendEvent(_currentSession.now!, SupportEvent.firstOpen);
    _handleResponse(hi);
  }

  clearSession() async {
    _currentSession.now = null;
    _chatHistory.now = null;
    messages = [];
    onChange();
  }

  sendMessage(String? message, {bool retry = false}) async {
    if (message?.startsWith("cc ") ?? false) {
      await _addMyMessage(message!);
      await _handleCommand(message.substring(3));
      return;
    }

    try {
      if (message != null) _addMyMessage(message);

      if (_currentSession.now == null) {
        await startSession();
      }

      if (message != null) {
        final msg = await _api.sendMessage(_currentSession.now!, message);
        _handleResponse(msg);
      }
    } on HttpCodeException catch (e) {
      if (e.code >= 400 && e.code < 500) {
        // Session bad or expired
        clearSession();
        if (!retry) {
          await startSession();
          await sendMessage(message, retry: true);
        } else {
          throw Exception("Retry failed: $e");
        }
      } else {
        throw Exception("Http error: $e");
      }
    } catch (e) {
      print("Error sending chat message");
      print(e);
      await sleepAsync(const Duration(milliseconds: 500));
      _addErrorMessage();
    }
    _updateSessionExpiry();
  }

  notifyNewMessage(Trace parentTrace) async {
    await sleepAsync(const Duration(seconds: 5));
    _notification.show(parentTrace, NotificationId.supportNewMessage);
    _unread.now = true;
  }

  _addMyMessage(String msg) {
    final message = SupportMessage(msg, DateTime.now(), isMe: true);
    messages.add(message);
    _chatHistory.now = SupportMessages(messages);
    onChange();
  }

  _handleResponse(JsonSupportResponse response) {
    for (final msg in response.messages) {
      if (msg.message == null) continue; // TODO: support other types of msgs

      final message = SupportMessage(
        msg.message!,
        DateTime.parse(msg.timestamp),
        isMe: !msg.isAgent,
      );
      _addMessage(message);
    }
  }

  _addMessage(SupportMessage message) {
    messages.add(message);
    messages.sort((a, b) => a.when.compareTo(b.when));
    _chatHistory.now = SupportMessages(messages);
    onChange();
  }

  _addErrorMessage({String? error}) {
    final message = SupportMessage(
      error ?? "Sorry did not understand, can you repeat?",
      DateTime.now(),
      isMe: false,
    );
    _addMessage(message);
  }

  _handleCommand(String message) async {
    await traceAs("supportCommand", (trace) async {
      try {
        await _command.onCommandString(trace, message);
        final msg = SupportMessage("OK", DateTime.now(), isMe: false);
        _addMessage(msg);
      } catch (e) {
        await sleepAsync(const Duration(milliseconds: 500));
        _addErrorMessage(error: e.toString());
        rethrow;
      }
    });
  }

  _updateSessionExpiry() {
    _scheduler.addOrUpdate(Job(
      _keyExpireSession,
      before: DateTime.now().add(Duration(seconds: _ttl)),
      callback: () async {
        clearSession();
        return false; // No reschedule
      },
    ));
  }
}
