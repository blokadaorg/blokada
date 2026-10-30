part of 'support.dart';

const _keyExpireSession = "supportExpireSession";

class SupportActor with Logging, Actor {
  late final _api = Core.get<SupportApi>();
  late final _command = Core.get<CommandStore>();
  late final _currentSession = Core.get<CurrentSession>();
  late final _sessionExpiry = Core.get<SupportSessionExpiry>();
  late final _chatHistory = Core.get<ChatHistory>();
  late final _unread = Core.get<SupportUnreadActor>();
  late final _scheduler = Core.get<Scheduler>();
  late final _logger = Core.get<LoggerChannel>();
  late final _isLocked = Core.get<IsLocked>();
  late final _stage = Core.get<StageStore>();
  late final _app = Core.get<AppStore>();
  late final _perm = Core.get<PlatformPermActor>();
  late String language = I18n.localeStr;

  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

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

  /// The agent's open request for a client tool, while its latest reply
  /// asks for one. The chat shows an approval card while this is set, so the
  /// user decides before the app acts.
  SupportAction? get action => _action;
  SupportAction? _action;
  DateTime? _actionAt;

  /// Follows the agent's latest reply: the card stays while that reply asks
  /// for a tool, and goes once a reply does not (including the one that
  /// answers the request). Rebuilt from the server history on load, so it
  /// survives an app restart.
  void _trackActions(List<JsonSupportHistoryItem> items) {
    for (final item in items.where((e) => e.isAgent)) {
      _action = item.actions.map(_toAction).firstOrNullWhere((e) => e != null);
      _actionAt = DateTime.tryParse(item.timestamp);
    }
  }

  /// Null for a tool this app does not know, or a dns_check without a usable
  /// name: the name becomes a host to look up.
  SupportAction? _toAction(JsonSupportAction e) {
    final tool = SupportClientTool.values.firstOrNullWhere((t) => t.constant == e.type);
    if (tool == null) return null;
    if (tool == SupportClientTool.dnsCheck &&
        !RegExp(r'^[a-z0-9]{12}$').hasMatch(e.subdomain ?? "")) {
      return null;
    }
    return SupportAction(tool, e.id, subdomain: e.subdomain);
  }

  @override
  onCreate(Marker m) async {
    _modal.onChange.listen((it) {
      if (it.now == Modal.support) {
        _modalWidget.change(it.m, (context) => const SupportSheet());
      }
    });
  }

  /// Opens the chat as a sheet over the current screen, for entry points
  /// outside Settings, where Chat with us pushes the full chat instead.
  /// Does nothing while the chat is already on screen, so there is never a
  /// second copy of it.
  ///
  /// The modal sheet shows one sheet at a time and drops a request made while
  /// another is up (such as a sheet shown at a cold start from the reply
  /// notification), so the chat waits for that one to be dismissed.
  Future<void> openSheet(Marker m) async {
    final current = _modal.present;
    if (current == Modal.support) return;
    if (current != null) {
      await _modal.onChange.firstWhere((it) => it.now == null);
    }
    if (_unread.isShowingChat) return;
    await _modal.change(m, Modal.support);
  }

  /// Opens the chat sheet from a help link on a screen where people get
  /// stuck. A chat that is still open goes on as it is, so the same problem
  /// never gets a second chat. Otherwise a new one starts with [event], which
  /// tells the agent where the user asked for help; the user sees the usual
  /// welcome.
  Future<void> askSupport(Marker m, SupportEvent event) async {
    final open = await isSessionOpen(m);
    // Started before the sheet, whose own load would open the chat with
    // FIRST_OPEN. Not awaited: the welcome shows in the sheet once it is in.
    unawaited(_logFailure(
      m,
      open ? loadOrInit(m, event: event) : startSession(m, event: event),
    ));
    await openSheet(m);
  }

  Future<void> _logFailure(Marker m, Future<void> work) async {
    try {
      await work;
    } catch (e, s) {
      log(m).e(msg: "Error opening support session", err: e, stack: s);
    }
  }

  /// Whether a chat is open, also after a cold start.
  Future<bool> isSessionOpen(Marker m) async {
    final id = await _currentSession.fetch(m);
    final expires = DateTime.tryParse(await _sessionExpiry.fetch(m) ?? "");
    return id != null && expires != null && expires.isAfter(DateTime.now());
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
    _trackActions(history);
    await _chatHistory.fetch(m);
    messages = _chatHistory.present?.messages ?? [];
    // The server history can still end with the request after it was
    // declined, or answered with no reply yet, so a note for the same tool
    // after the latest request keeps the card hidden across restarts.
    final handled = messages.lastOrNullWhere(
      (e) => e.note != null && e.note?.tool == _action?.tool,
    );
    if (handled != null && _actionAt != null && handled.when.isAfter(_actionAt!)) {
      _action = null;
    }

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
    await _updateSessionExpiry(m);
    await _handleResponse(m, session.history);
  }

  clearSession(Marker m) async {
    await _currentSession.change(m, null);
    await _sessionExpiry.change(m, null);
    await _chatHistory.change(m, null);
    messages = [];
    _action = null;
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
    await _updateSessionExpiry(m);
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
    await _updateSessionExpiry(m);
  }

  /// Runs the tool of the card the user approved.
  Future<void> approveAction(Marker m) async {
    switch (_action?.tool) {
      case SupportClientTool.attachLog:
        return shareLog(m);
      case SupportClientTool.dnsCheck:
        return runDnsCheck(m);
      case null:
        return;
    }
  }

  /// Uploads the end of the app log for the agent's open request, from the
  /// share log button, and shows the agent's reply to it.
  ///
  /// The log can hold details of the user's setup, so a locked app refuses
  /// it, the same as sharing the log from settings.
  Future<void> shareLog(Marker m) async {
    if (_action?.tool != SupportClientTool.attachLog || _replyPending) return;
    if (_isLocked.now) {
      await _stage.showModal(StageModal.faultLocked, m);
      return;
    }

    await _answerAction(m, "Error uploading log", (sessionId, action) async {
      final appLog = capLogTail(
          await _logger.doReadLogTail(supportLogMaxBytes), supportLogMaxBytes);
      if (appLog.isEmpty) throw Exception("App log is empty");
      return _api.uploadLog(m, sessionId, action.id, appLog);
    });
  }

  /// Resolves the agent's test name with the phone's own resolver and
  /// reports it with what the app knows of its setup, then shows the reply.
  Future<void> runDnsCheck(Marker m) async {
    if (_action?.tool != SupportClientTool.dnsCheck) return;
    await _answerAction(m, "Error reporting DNS check", (sessionId, action) async {
      final resolved = await resolveHost("${action.subdomain}.test.blokada.org");
      final status = _app.status;
      final paused =
          status == AppStatus.paused || status == AppStatus.pausedPlus || _app.conditions.appPaused;
      final state = {
        "protection": paused
            ? "paused"
            : status.isActive()
            ? "on"
            : "off",
        "system_dns": await _perm.systemDnsSetting(m),
        "vpn": _app.conditions.plusActive ? "on" : "off",
        "lookup": resolved ? "ok" : "failed",
      };
      return _api.reportDnsCheck(m, sessionId, action.id, language, state);
    });
  }

  /// Whether the system resolver answers for [host]; replaceable in tests.
  Future<bool> Function(String host) resolveHost = (host) async {
    try {
      return (await InternetAddress.lookup(host).timeout(const Duration(seconds: 6))).isNotEmpty;
    } catch (_) {
      return false;
    }
  };

  /// Performs the request of the open card with [call], which returns the
  /// agent's reply, and leaves the note for it.
  ///
  /// Uses the pending-reply state like a sent message: the call starts an
  /// agent turn, and a second tap or a message meanwhile would race it.
  Future<void> _answerAction(
    Marker m,
    String errorMsg,
    Future<JsonSupportResponse> Function(String sessionId, SupportAction action) call,
  ) async {
    final action = _action;
    final sessionId = _currentSession.present;
    if (action == null || sessionId == null || _replyPending) return;

    final done = SupportNote.of(action.tool, declined: false);
    _setReplyPending(true);
    try {
      final response = await call(sessionId, action);
      _action = null;
      await _addNote(m, done, response.messages);
      if (response.messages != null) {
        await _handleResponse(m, response.messages!, isReply: true);
      }
    } on HttpCodeException catch (e, s) {
      log(m).e(msg: errorMsg, err: e, stack: s);
      // A 4xx will not pass on retry: the request is closed, or (409) the
      // log is already there from an earlier try.
      if (e.code >= 400 && e.code < 500) _action = null;
      if (e.code == 409) await _addNote(m, done, null);
      if (e.code != 409) await _stage.showModal(StageModal.fault, m);
    } catch (e, s) {
      log(m).e(msg: errorMsg, err: e, stack: s);
      await _stage.showModal(StageModal.fault, m);
    } finally {
      _setReplyPending(false);
      // The button may have changed without a reply to redraw it.
      onChange();
    }
    await _updateSessionExpiry(m);
  }

  /// Turns down the agent's open request, leaving a note in the history.
  /// A later reply that asks again shows the card again.
  Future<void> declineAction(Marker m) async {
    final action = _action;
    if (action == null || _replyPending) return;
    _action = null;
    await _addNote(m, SupportNote.of(action.tool, declined: true), null);
    onChange();
  }

  /// Leaves a note in the history, just ahead of the agent's reply or,
  /// without one, just after the request. Both carry the server's clock, so
  /// the restart check in [_loadChatHistory] never compares device time.
  Future<void> _addNote(Marker m, SupportNote note, List<JsonSupportHistoryItem>? reply) async {
    final first = reply?.firstOrNullWhere((e) => e.text?.isBlank == false);
    final when = first != null
        ? DateTime.parse(first.timestamp).subtract(const Duration(milliseconds: 1))
        : _actionAt?.add(const Duration(milliseconds: 1)) ?? DateTime.now();
    final message = SupportMessage.note(note, when);
    messages.add(message);
    messages.sort((a, b) => a.when.compareTo(b.when));
    await _chatHistory.change(m, SupportMessages(messages));
    await controller.insertMessage(message.toFlyerMessage(me, notMe));
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
    _trackActions(messages);
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

  _updateSessionExpiry(Marker m) async {
    final expires = DateTime.now().add(Duration(seconds: _ttl));
    await _sessionExpiry.change(m, expires.toIso8601String());
    await _scheduler.addOrUpdate(Job(
      _keyExpireSession,
      Markers.support,
      before: expires,
      callback: (m) async {
        clearSession(m);
        return false; // No reschedule
      },
    ));
  }
}
