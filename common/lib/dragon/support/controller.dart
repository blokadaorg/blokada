import 'dart:math';

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
const _expireSessionTime = Duration(minutes: 2);

class SupportController with TraceOrigin {
  late final _api = dep<SupportApi>();
  late final _command = dep<CommandStore>();
  late final _notification = dep<NotificationStore>();
  late final _currentSession = dep<CurrentSession>();
  late final _chatHistory = dep<ChatHistory>();
  late final _unread = dep<SupportUnread>();
  late final _scheduler = dep<Scheduler>();

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

  resetSession() async {
    final id = _newSession();
    _currentSession.now = id;
    messages = [];
    _chatHistory.now = null;
    final hi = await _api.sendEvent(
        _currentSession.now!, language, SupportEvent.firstOpen);
    _addMessage(hi);
  }

  sendMessage(String? message) async {
    if (message?.startsWith("cc ") ?? false) {
      await _addMyMessage(message!);
      await _handleCommand(message.substring(3));
      return;
    }

    try {
      if (message != null) _addMyMessage(message);

      if (_currentSession.now == null) {
        await resetSession();
      }

      if (message != null) {
        final msg =
            await _api.sendMessage(_currentSession.now!, language, message);
        _addMessage(msg);
        print("Api message: '${msg.message}'");
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

  _addMessage(JsonSupportMessage msg) {
    final message = SupportMessage(msg.message, DateTime.now(), isMe: false);
    messages.add(message);
    _chatHistory.now = SupportMessages(messages);
    onChange();
  }

  _addErrorMessage({String? error}) {
    final message = SupportMessage(
      error ?? "Sorry did not understand, can you repeat?",
      DateTime.now(),
      isMe: false,
    );
    messages.add(message);
    _chatHistory.now = SupportMessages(messages);
    onChange();
  }

  String _newSession() {
    // Taken from web app
    // Math.random().toString(36).substring(2, 15)

    return Random().nextDouble().toStringAsFixed(15).substring(2, 15);
  }

  _handleCommand(String message) async {
    await traceAs("supportCommand", (trace) async {
      try {
        await _command.onCommandString(trace, message);
        final msg = SupportMessage("OK", DateTime.now(), isMe: false);
        messages.add(msg);
        _chatHistory.now = SupportMessages(messages);
        onChange();
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
      before: DateTime.now().add(_expireSessionTime),
      callback: () async {
        _currentSession.now = null;
        _chatHistory.now = null;
        onChange();
        return false; // No reschedule
      },
    ));
  }
}
