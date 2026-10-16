part of 'support.dart';

const _keyExpireSession = "supportExpireSession";

class SupportActor with Logging, Actor {
  late final _api = Core.get<SupportApi>();
  late final _command = Core.get<CommandStore>();
  late final _currentSession = Core.get<CurrentSession>();
  late final _chatHistory = Core.get<ChatHistory>();
  late final _unread = Core.get<SupportUnreadActor>();
  late final _scheduler = Core.get<Scheduler>();
  late String language = I18n.localeStr;

  bool initialized = false;
  late int _ttl;

  late ChatController controller = InMemoryChatController();
  List<SupportMessage> messages = [];

  final me = const User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ac');
  final notMe = const User(
    id: 'f590b0b3-3b6b-4b7b-8b3b-3b6b4b7b8b3b',
    name: "Blocka Bot",
    //imageUrl: "assets/images/appicon.png",
  );

  Function onChange = () {};

  /// True from the moment a user message goes out until the bot's reply, or
  /// the error message standing in for it, is in the chat.
  ///
  /// Replies take seconds, and without a visible sign of progress the chat
  /// looks stuck, which makes people send again and start another bot turn.
  /// The chat shows a typing indicator and blocks sending while this is set.
  bool get replyPending => _replyPending;
  bool _replyPending = false;

  void _setReplyPending(bool pending) {
    if (_replyPending == pending) return;
    _replyPending = pending;
    onChange();
  }

  // Return true if session was just created
  Future<bool> loadOrInit(Marker m, {SupportEvent? event}) async {
    if (initialized) return false;
    initialized = true;

    await _currentSession.fetch(m);

    if (_currentSession.present != null) {
      try {
        final session = await _api.getSession(m, _currentSession.present!);
        _ttl = session.ttl;
        if (_ttl < 0) throw Exception("Session expired");
        await _loadChatHistory(m, session.history);
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
    if (_currentSession.present == null) {
      await startSession(m);
    }
  }

  /// Session start that is already running, if any.
  Future<void>? _startingSession;

  _loadChatHistory(Marker m, List<JsonSupportHistoryItem> history) async {
    await _chatHistory.fetch(m);
    messages = _chatHistory.present?.messages ?? [];

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
    await _chatHistory.change(m, SupportMessages(messages));
    await controller.insertAllMessages(
        messages.map((it) => it.toFlyerMessage(me, notMe)).toList());
    onChange();
  }

  /// Starts a session, or joins the one that is already starting.
  ///
  /// Joining matters because the session id is cleared before the create call
  /// and only stored when it returns: anything that checks "do we have a
  /// session?" during that round trip would otherwise start a second one. The
  /// support screen does exactly that — it re-arms a debounced
  /// [maybeStartSession] on every rebuild — which showed up as the opening
  /// greeting arriving twice on an install with no stored session.
  Future<void> startSession(Marker m, {SupportEvent? event}) {
    final pending = _startingSession;
    if (pending != null) return pending;

    final starting = _startSession(m, event: event);
    _startingSession = starting;
    return starting.whenComplete(() {
      if (identical(_startingSession, starting)) _startingSession = null;
    });
  }

  Future<void> _startSession(Marker m, {SupportEvent? event}) async {
    // The new session replaces any stored one, so there is nothing to load.
    // loadOrInit would start a session itself and wait on this one forever.
    initialized = true;
    await clearSession(m);
    final session = await _api.createSession(m, language, event: event);
    await _currentSession.change(m, session.sessionId);
    _ttl = session.ttl;
    await _updateSessionExpiry();
    await _handleResponse(m, session.history);
  }

  clearSession(Marker m) async {
    await _currentSession.change(m, null);
    await _chatHistory.change(m, null);
    messages = [];
    await controller.setMessages([]);
    onChange();
  }

  /// Sends a user message (or a local `cc ` command) and posts the reply.
  ///
  /// Owns the [replyPending] lifecycle around [_sendMessage], so that every
  /// way out, including a rethrow, clears the flag in one place.
  sendMessage(String? message, Marker m, {bool retrying = false}) async {
    final command = message?.startsWith("cc ") ?? false;
    // Set before the first await: a send that first has to open a session
    // waits on that round trip too, and must already block a second send.
    if (message != null && !command) _setReplyPending(true);
    try {
      await _sendMessage(message, m, command: command, retrying: retrying);
    } finally {
      // Covers the paths that rethrow without posting an error message.
      _setReplyPending(false);
    }
  }

  /// The send itself, split from [sendMessage] so the pending flag wraps it
  /// from outside. A 4xx retry calls back into [sendMessage], which keeps the
  /// flag set for the retry and clears it once the retry is done.
  Future<void> _sendMessage(String? message, Marker m,
      {required bool command, required bool retrying}) async {
    await loadOrInit(m);
    if (command) {
      await _addMyMessage(m, message!);
      await _handleCommand(message.substring(3), m);
      return;
    }

    try {
      if (_currentSession.present == null) {
        await startSession(m);
      }

      if (message != null) {
        _addMyMessage(m, message);
        final msg =
            await _api.sendMessage(m, _currentSession.present!, message);
        if (msg.messages != null) {
          await _handleResponse(m, msg.messages!, isReply: true);
        }
      }
    } on HttpCodeException catch (e) {
      if (e.code >= 400 && e.code < 500) {
        // Session bad or expired
        clearSession(m);
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
      if (_currentSession.present == null) {
        await startSession(m, event: event);
      } else if (!sessionJustStarted) {
        final msg = await _api.sendEvent(m, _currentSession.present!, event);
        if (msg.messages != null) await _handleResponse(m, msg.messages!);
      }
    } on HttpCodeException catch (e) {
      if (e.code >= 400 && e.code < 500) {
        // Session bad or expired
        clearSession(m);
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

  _addMyMessage(Marker m, String msg) {
    final message = SupportMessage(msg, DateTime.now(), isMe: true);
    messages.add(message);
    _chatHistory.change(m, SupportMessages(messages));
    controller.insertMessage(message.toFlyerMessage(me, notMe));
    onChange();
  }

  /// [isReply] marks the bot's answer to a user message, whose first shown
  /// message ends the pending-reply wait.
  _handleResponse(Marker m, List<JsonSupportHistoryItem> messages,
      {bool isReply = false}) async {
    for (final msg in messages) {
      if (msg.text == null || msg.text!.isBlank) {
        continue; // TODO: support other types of msgs
      }

      final message = SupportMessage(
        msg.text!,
        DateTime.parse(msg.timestamp),
        isMe: !msg.isAgent,
      );
      await _addMessage(m, message, endsPendingReply: isReply);
    }
  }

  /// [endsPendingReply] clears [replyPending] only once the message is in the
  /// chat controller, and in the same UI update: clearing earlier would let a
  /// second send through while the reply is still being stored, and clearing
  /// later would show the indicator next to the reply.
  _addMessage(m, SupportMessage message,
      {bool endsPendingReply = false}) async {
    messages.add(message);
    messages.sort((a, b) => a.when.compareTo(b.when));
    await _chatHistory.change(m, SupportMessages(messages));
    await controller.insertMessage(message.toFlyerMessage(me, notMe));
    if (endsPendingReply) _replyPending = false;
    onChange();
    await _unread.newMessage(m, message.text);
  }

  _addErrorMessage(Marker m, {String? error}) async {
    final message = SupportMessage(
      error ?? "Sorry did not understand, can you repeat?", // TODO: localize
      DateTime.now(),
      isMe: false,
    );
    // An error message stands in for the reply, so it ends the wait too.
    await _addMessage(m, message, endsPendingReply: true);
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
        clearSession(m);
        return false; // No reschedule
      },
    ));
  }
}
