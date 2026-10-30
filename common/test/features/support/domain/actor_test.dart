import 'dart:async';
import 'dart:convert';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/command/command.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';

@GenerateNiceMocks([
  MockSpec<SupportApi>(),
  MockSpec<CommandStore>(),
  MockSpec<SupportUnreadActor>(),
  MockSpec<Scheduler>(),
  MockSpec<Persistence>(),
  MockSpec<LoggerChannel>(),
  MockSpec<StageStore>(),
  MockSpec<AppStore>(),
  MockSpec<PlatformPermActor>(),
])
import 'actor_test.mocks.dart';

JsonSupportSession _session(String id) => JsonSupportSession(
      sessionId: id,
      history: [
        JsonSupportHistoryItem(
          text: "Hello! I'm Blocka Bot",
          isAgent: true,
          timestamp: DateTime(2026, 9, 7, 12).toIso8601String(),
        )
      ],
      created: DateTime(2026, 9, 7, 12).toIso8601String(),
      ttl: 3600,
    );

JsonSupportResponse _reply(String text) => JsonSupportResponse(
      messages: [
        JsonSupportHistoryItem(
          text: text,
          isAgent: true,
          // After the user message, so it sorts last like a real reply.
          timestamp: DateTime.now().add(const Duration(seconds: 1)).toIso8601String(),
        )
      ],
    );

/// Registers everything SupportActor resolves, with no stored session, which
/// is the state a fresh install starts in.
MockSupportApi _registerDeps() {
  final api = MockSupportApi();
  Core.register<SupportApi>(api);
  Core.register<CommandStore>(MockCommandStore());
  Core.register<SupportUnreadActor>(MockSupportUnreadActor());
  Core.register<Scheduler>(MockScheduler());

  final persistence = MockPersistence();
  when(persistence.load(any, any)).thenAnswer((_) => Future.value(null));
  when(persistence.save(any, any, any, isBackup: anyNamed("isBackup")))
      .thenAnswer((_) async {});
  when(persistence.delete(any, any, isBackup: anyNamed("isBackup")))
      .thenAnswer((_) async {});
  Core.register<Persistence>(persistence);

  Core.register(CurrentSession());
  Core.register(ChatHistory());
  // withTrace registers a no-op one; these tests control what it reads.
  Core.di.unregister<LoggerChannel>(instanceName: "default");
  Core.register<LoggerChannel>(MockLoggerChannel());
  Core.register<StageStore>(MockStageStore());
  Core.register(IsLocked());
  return api;
}

JsonSupportResponse _logRequest(String text, String actionId) =>
    JsonSupportResponse(
      messages: [
        JsonSupportHistoryItem(
          text: text,
          isAgent: true,
          timestamp:
              DateTime.now().add(const Duration(seconds: 1)).toIso8601String(),
          actions: [JsonSupportAction(type: "attach_log", id: actionId)],
        )
      ],
    );

JsonSupportResponse _dnsRequest(String subdomain) => JsonSupportResponse(
      messages: [
        JsonSupportHistoryItem(
          text: "Let me check your DNS",
          isAgent: true,
          timestamp:
              DateTime.now().add(const Duration(seconds: 1)).toIso8601String(),
          actions: [
            JsonSupportAction(
                type: "dns_check", id: "chk-1", subdomain: subdomain)
          ],
        )
      ],
    );

/// A session whose agent has asked for the log, through a reply to "hi".
Future<SupportActor> _askedForLog(Marker m, MockSupportApi api) async {
  when(api.createSession(any, any, event: anyNamed("event")))
      .thenAnswer((_) async => _session("session-1"));
  when(api.sendMessage(any, any, any))
      .thenAnswer((_) async => _logRequest("Please share your log", "act-1"));
  final subject = SupportActor();
  await subject.loadOrInit(m);
  await subject.sendMessage("hi", m);
  return subject;
}

void main() {
  group("startSession", () {
    test("callers arriving mid-flight join it instead of opening a second one",
        () async {
      await withTrace((m) async {
        final api = _registerDeps();
        // Hold the create call open, which is the window the second caller
        // used to slip through: the session id is already cleared, so it still
        // looks like there is no session.
        final pending = Completer<JsonSupportSession>();
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) => pending.future);

        final subject = SupportActor();
        final first = subject.startSession(m);
        final second = subject.maybeStartSession(m);

        pending.complete(_session("session-1"));
        await first;
        await second;

        verify(api.createSession(any, any, event: anyNamed("event")))
            .called(1);
        expect(subject.messages.length, 1);
      });
    });

    test("a later start still opens a new session", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        var created = 0;
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) async => _session("session-${++created}"));

        final subject = SupportActor();
        await subject.startSession(m);
        await subject.startSession(m);

        verify(api.createSession(any, any, event: anyNamed("event")))
            .called(2);
      });
    });

    test("maybeStartSession is a no-op once a session exists", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) async => _session("session-1"));

        final subject = SupportActor();
        await subject.startSession(m);
        await subject.maybeStartSession(m);

        verify(api.createSession(any, any, event: anyNamed("event")))
            .called(1);
      });
    });
  });

  group("replyPending", () {
    test("is set while the reply is on its way and cleared once it is in",
        () async {
      await withTrace((m) async {
        final api = _registerDeps();
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) async => _session("session-1"));
        final pending = Completer<JsonSupportResponse>();
        when(api.sendMessage(any, any, any))
            .thenAnswer((_) => pending.future);

        final subject = SupportActor();
        await subject.loadOrInit(m);
        expect(subject.replyPending, false);

        final sending = subject.sendMessage("hi", m);
        await pumpEventQueue();
        expect(subject.replyPending, true);

        // The flag clears before the reply is added, so the indicator and
        // the reply are never shown together.
        final seenWhenReplyAdded = <bool>[];
        subject.onChange = () {
          if (subject.messages.last.text == "Hello there") {
            seenWhenReplyAdded.add(subject.replyPending);
          }
        };
        pending.complete(_reply("Hello there"));
        await sending;

        expect(subject.replyPending, false);
        expect(subject.messages.last.text, "Hello there");
        expect(seenWhenReplyAdded, isNotEmpty);
        expect(seenWhenReplyAdded, everyElement(false));
      });
    });

    test("stays set until the reply is in the chat, even if storing is slow",
        () async {
      await withTrace((m) async {
        final api = _registerDeps();
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) async => _session("session-1"));
        when(api.sendMessage(any, any, any))
            .thenAnswer((_) async => _reply("Hello there"));

        final subject = SupportActor();
        await subject.loadOrInit(m);

        // Hold the history write of the reply open.
        final storingStarted = Completer<void>();
        final storing = Completer<void>();
        final persistence = Core.get<Persistence>() as MockPersistence;
        when(persistence.save(any, "support_chat_history", any,
                isBackup: anyNamed("isBackup")))
            .thenAnswer((inv) async {
          final json = inv.positionalArguments[2] as String;
          if (json.contains("Hello there")) {
            storingStarted.complete();
            await storing.future;
          }
        });

        final sending = subject.sendMessage("hi", m);
        await storingStarted.future;
        // The API answered, but the reply is not in the chat yet: a second
        // send must still be blocked.
        expect(subject.replyPending, true);

        storing.complete();
        await sending;
        expect(subject.replyPending, false);
      });
    });

    test("is set right away when the send first has to open a session",
        () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final creating = Completer<JsonSupportSession>();
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) => creating.future);
        when(api.sendMessage(any, any, any))
            .thenAnswer((_) async => _reply("Hello there"));

        final subject = SupportActor();
        final sending = subject.sendMessage("hi", m);
        // Set before the first await, so a second send during the session
        // round trip is already refused.
        expect(subject.replyPending, true);

        creating.complete(_session("session-1"));
        await sending;
        expect(subject.replyPending, false);
      });
    });

    for (final text in ["cc info", "Cc restore abcdefghijkl"]) {
      test("goes to the support bot for '$text', which runs no command",
          () async {
        await withTrace((m) async {
          final api = _registerDeps();
          when(api.createSession(any, any, event: anyNamed("event")))
              .thenAnswer((_) async => _session("session-1"));
          when(api.sendMessage(any, any, any))
              .thenAnswer((_) async => _reply("Hello there"));

          final subject = SupportActor();
          final sending = subject.sendMessage(text, m);
          expect(subject.replyPending, true);
          await sending;

          verify(api.sendMessage(any, any, text)).called(1);
          final command = Core.get<CommandStore>() as MockCommandStore;
          verifyNever(command.onCommandString(any, any));
          expect(subject.messages.last.text, "Hello there");
        });
      });
    }

    test("is cleared when the request fails and the error message shows",
        () async {
      await withTrace((m) async {
        final api = _registerDeps();
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) async => _session("session-1"));
        when(api.sendMessage(any, any, any))
            .thenAnswer((_) async => throw Exception("offline"));

        final subject = SupportActor();
        await subject.loadOrInit(m);
        final before = subject.messages.length;

        await subject.sendMessage("hi", m);

        expect(subject.replyPending, false);
        // Own message plus the error reply.
        expect(subject.messages.length, before + 2);
        expect(subject.messages.last.isMe, false);
      });
    });

    test("is cleared when a server error is rethrown", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) async => _session("session-1"));
        when(api.sendMessage(any, any, any))
            .thenAnswer((_) async => throw HttpCodeException(503, "down"));

        final subject = SupportActor();
        await subject.loadOrInit(m);

        await expectLater(subject.sendMessage("hi", m), throwsException);
        expect(subject.replyPending, false);
      });
    });
  });

  group("shareLog", () {
    test("a reply asking for the log shows the button, a later one hides it",
        () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final subject = await _askedForLog(m, api);
        expect(subject.action?.id, "act-1");

        when(api.sendMessage(any, any, any))
            .thenAnswer((_) async => _reply("Anything else?"));
        await subject.sendMessage("what log?", m);
        expect(subject.action?.id, isNull);
      });
    });

    test("no button without an attach_log action", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) async => _session("session-1"));
        when(api.sendMessage(any, any, any))
            .thenAnswer((_) async => _reply("Hello there"));
        final subject = SupportActor();
        await subject.loadOrInit(m);
        await subject.sendMessage("hi", m);
        expect(subject.action?.id, isNull);

        await subject.shareLog(m);
        verifyNever(api.uploadLog(any, any, any, any));
      });
    });

    test("uploads the log tail and shows the agent's reply", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final logger = Core.get<LoggerChannel>() as MockLoggerChannel;
        when(logger.doReadLogTail(any)).thenAnswer((_) async => "line 1\n");
        final subject = await _askedForLog(m, api);
        when(api.uploadLog(any, any, any, any))
            .thenAnswer((_) async => _reply("Thanks, I have the log"));
        var saved = "";
        when((Core.get<Persistence>() as MockPersistence).save(
                any, "support_chat_history", any,
                isBackup: anyNamed("isBackup")))
            .thenAnswer((inv) async {
          saved = inv.positionalArguments[2] as String;
        });

        await subject.shareLog(m);

        verify(logger.doReadLogTail(supportLogMaxBytes)).called(1);
        verify(api.uploadLog(any, "session-1", "act-1", "line 1\n")).called(1);
        expect(subject.messages.last.text, "Thanks, I have the log");
        expect(subject.messages.indexWhere((e) => e.note == SupportNote.logShared),
            lessThan(subject.messages.length - 1),
            reason: "the note comes before the agent's reply");
        expect(subject.action?.id, isNull);

        // The note is stored with the history and comes back after a reload.
        final reloaded = SupportMessages.fromJson(jsonDecode(saved));
        expect(reloaded.messages.where((e) => e.note == SupportNote.logShared).length, 1);
        expect(subject.replyPending, false);
      });
    });

    test("a locked app shows the locked fault and uploads nothing", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final subject = await _askedForLog(m, api);
        Core.get<IsLocked>().now = true;

        await subject.shareLog(m);

        verify(Core.get<StageStore>().showModal(StageModal.faultLocked, m))
            .called(1);
        verifyNever(
            (Core.get<LoggerChannel>() as MockLoggerChannel).doReadLogTail(any));
        verifyNever(api.uploadLog(any, any, any, any));
        expect(subject.action?.id, "act-1");
      });
    });

    test("a server error keeps the button for another try", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final logger = Core.get<LoggerChannel>() as MockLoggerChannel;
        when(logger.doReadLogTail(any)).thenAnswer((_) async => "line 1\n");
        final subject = await _askedForLog(m, api);
        when(api.uploadLog(any, any, any, any))
            .thenAnswer((_) async => throw HttpCodeException(503, "down"));

        await subject.shareLog(m);

        verify(Core.get<StageStore>().showModal(StageModal.fault, m))
            .called(1);
        expect(subject.action?.id, "act-1");
        expect(subject.replyPending, false);
      });
    });

    test("a closed request removes the button", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final logger = Core.get<LoggerChannel>() as MockLoggerChannel;
        when(logger.doReadLogTail(any)).thenAnswer((_) async => "line 1\n");
        final subject = await _askedForLog(m, api);
        when(api.uploadLog(any, any, any, any))
            .thenAnswer((_) async => throw HttpCodeException(400, "closed"));

        await subject.shareLog(m);

        verify(Core.get<StageStore>().showModal(StageModal.fault, m))
            .called(1);
        expect(subject.action?.id, isNull);
        expect(subject.messages.any((e) => e.note == SupportNote.logShared), false);
      });
    });

    test("the button comes back from the session history after a restart",
        () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final persistence = Core.get<Persistence>() as MockPersistence;
        when(persistence.load(any, "support_session_id"))
            .thenAnswer((_) async => "session-1");
        when(api.getSession(any, "session-1")).thenAnswer((_) async =>
            JsonSupportSession(
              sessionId: "session-1",
              history: _logRequest("Please share your log", "act-1").messages!,
              created: DateTime(2026, 9, 7, 12).toIso8601String(),
              ttl: 3600,
            ));

        final subject = SupportActor();
        await subject.loadOrInit(m);
        expect(subject.action?.id, "act-1");
      });
    });
  });

  group("runDnsCheck", () {
    Future<SupportActor> asked(Marker m, MockSupportApi api,
        [String subdomain = "k3x9q0b7m2ta"]) async {
      when(api.createSession(any, any, event: anyNamed("event")))
          .thenAnswer((_) async => _session("session-1"));
      when(api.sendMessage(any, any, any))
          .thenAnswer((_) async => _dnsRequest(subdomain));
      final app = MockAppStore();
      when(app.status).thenReturn(AppStatus.activatedPlus);
      when(app.conditions)
          .thenReturn(AppStatusStrategy(plusActive: true, appPaused: false));
      Core.register<AppStore>(app);
      final perm = MockPlatformPermActor();
      when(perm.systemDnsSetting(any)).thenAnswer((_) async => "blokada");
      Core.register<PlatformPermActor>(perm);
      final subject = SupportActor();
      subject.resolveHost = (_) async => true;
      await subject.loadOrInit(m);
      await subject.sendMessage("hi", m);
      return subject;
    }

    test("posts the check with the action id and the app state", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final subject = await asked(m, api);
        expect(subject.action?.tool, SupportClientTool.dnsCheck);
        String? host;
        subject.resolveHost = (h) async {
          host = h;
          return true;
        };
        when(api.reportDnsCheck(any, any, any, any, any))
            .thenAnswer((_) async => _reply("Your DNS goes through Blokada"));

        await subject.approveAction(m);

        expect(host, "k3x9q0b7m2ta.test.blokada.org");
        verify(api.reportDnsCheck(any, "session-1", "chk-1", any, {
          "protection": "on",
          "system_dns": "blokada",
          "vpn": "on",
          "lookup": "ok",
        })).called(1);
        expect(subject.messages.last.text, "Your DNS goes through Blokada");
        expect(subject.messages.any((e) => e.note == SupportNote.dnsChecked),
            true);
        expect(subject.action, isNull);
        expect(subject.replyPending, false);
      });
    });

    test("a failed lookup is reported as failed", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final subject = await asked(m, api);
        subject.resolveHost = (_) async => false;
        when(api.reportDnsCheck(any, any, any, any, any))
            .thenAnswer((_) async => _reply("Not through Blokada"));

        await subject.approveAction(m);

        verify(api.reportDnsCheck(any, any, any, any,
            argThat(containsPair("lookup", "failed")))).called(1);
      });
    });

    test("cancel leaves a note and posts nothing", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final subject = await asked(m, api);

        await subject.declineAction(m);

        expect(subject.action, isNull);
        expect(subject.messages.any((e) => e.note == SupportNote.dnsDeclined),
            true);
        verifyNever(api.reportDnsCheck(any, any, any, any, any));
      });
    });

    test("a server error keeps the card for another try", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final subject = await asked(m, api);
        when(api.reportDnsCheck(any, any, any, any, any))
            .thenAnswer((_) async => throw HttpCodeException(503, "down"));

        await subject.approveAction(m);

        verify(Core.get<StageStore>().showModal(StageModal.fault, m))
            .called(1);
        expect(subject.action?.id, "chk-1");
        expect(subject.replyPending, false);
      });
    });

    test("a name that is not a test subdomain shows no card", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final subject = await asked(m, api, "evil.example.com/x");
        expect(subject.action, isNull);
      });
    });

    test("a shared log keeps the button away after a restart", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        final request = _logRequest("Please share your log", "act-1");
        final requestedAt = DateTime.parse(request.messages!.first.timestamp);
        final persistence = Core.get<Persistence>() as MockPersistence;
        when(persistence.load(any, "support_session_id"))
            .thenAnswer((_) async => "session-1");
        // Shared with no agent reply yet, so the server still ends with the request.
        when(persistence.load(any, "support_chat_history")).thenAnswer(
            (_) async => jsonEncode(SupportMessages([
                  SupportMessage.note(SupportNote.logShared,
                      requestedAt.add(const Duration(milliseconds: 1)))
                ]).toJson()));
        when(api.getSession(any, "session-1")).thenAnswer((_) async =>
            JsonSupportSession(
              sessionId: "session-1",
              history: request.messages!,
              created: DateTime(2026, 9, 7, 12).toIso8601String(),
              ttl: 3600,
            ));

        final subject = SupportActor();
        await subject.loadOrInit(m);
        expect(subject.action, isNull);
      });
    });

    test("a decline sorts after the request on the server's clock", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        // The server clock is an hour ahead of the device.
        final requestedAt = DateTime.now().add(const Duration(hours: 1));
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) async => _session("session-1"));
        when(api.sendMessage(any, any, any))
            .thenAnswer((_) async => JsonSupportResponse(messages: [
                  JsonSupportHistoryItem(
                    text: "Please share your log",
                    isAgent: true,
                    timestamp: requestedAt.toIso8601String(),
                    actions: [
                      JsonSupportAction(type: "attach_log", id: "act-1")
                    ],
                  )
                ]));
        final subject = SupportActor();
        await subject.loadOrInit(m);
        await subject.sendMessage("hi", m);

        await subject.declineAction(m);

        final declined = subject.messages.lastWhere((e) => e.note == SupportNote.logDeclined);
        expect(declined.when.isAfter(requestedAt), isTrue);
      });
    });
  });

  group("capLogTail", () {
    test("keeps a log within the limit as is", () {
      expect(capLogTail("a\nb\n", 10), "a\nb\n");
    });

    test("drops the oldest lines and starts at a line boundary", () {
      expect(capLogTail("first line\nsecond\nthird\n", 13), "second\nthird\n");
      expect(capLogTail("first line\nsecond\nthird\n", 12), "third\n");
    });

    test("never cuts inside a character", () {
      final out = capLogTail("ééééé", 5);
      expect(out, "éé");
      expect(utf8.encode(out).length, lessThanOrEqualTo(5));
    });
  });

  group("json", () {
    test("a new session declares the client tools", () {
      final payload = jsonDecode(JsonSupportMarshal().fromCreateSession(
          JsonSupportPayloadCreateSession(
              language: "en", clientTools: SupportClientTool.values)));
      expect(payload["client_tools"], ["attach_log", "dns_check"]);
    });

    test("a message carries the user agent and client tools", () {
      final payload = jsonDecode(JsonSupportMarshal().fromMessage(
          JsonSupportPayloadMessage(
              sessionId: "s",
              userAgent: 'blokada/26.1.1 (android-35 "x")',
              message: "my (user_agent) is",
              clientTools: SupportClientTool.values)));
      expect(payload["user_agent"], 'blokada/26.1.1 (android-35 "x")');
      expect(payload["message"], "my (user_agent) is");
      expect(payload["client_tools"], ["attach_log", "dns_check"]);
    });

    test("parses actions on an agent message, and none when absent", () {
      final response = JsonSupportMarshal().toResponse(jsonEncode({
        "messages": [
          {
            "content": {"text": "a", "event": ""},
            "is_agent": true,
            "timestamp": "2026-10-12T10:03:00Z",
          },
          {
            "content": {
              "text": "b",
              "event": "",
              "actions": [
                {"type": "attach_log", "id": "Qm9x"}
              ],
            },
            "is_agent": true,
            "timestamp": "2026-10-12T10:03:01Z",
          },
        ]
      }));
      expect(response.messages![0].actions, isEmpty);
      expect(response.messages![1].actions.single.type, "attach_log");
      expect(response.messages![1].actions.single.id, "Qm9x");
    });

    test("treats a malformed actions field as none and keeps the message", () {
      final response = JsonSupportMarshal().toResponse(jsonEncode({
        "messages": [
          {
            "content": {"text": "a", "event": "", "actions": "attach_log"},
            "is_agent": true,
            "timestamp": "2026-10-12T10:03:00Z",
          },
        ]
      }));
      expect(response.messages!.single.text, "a");
      expect(response.messages!.single.actions, isEmpty);
    });

    test("drops a malformed action and keeps the message", () {
      final response = JsonSupportMarshal().toResponse(jsonEncode({
        "messages": [
          {
            "content": {
              "text": "a",
              "event": "",
              "actions": [
                {"type": "attach_log"},
                {"type": "dns_check", "id": "Zx8r", "subdomain": 42},
                {"type": "attach_log", "id": "Qm9x"}
              ],
            },
            "is_agent": true,
            "timestamp": "2026-10-12T10:03:00Z",
          },
        ]
      }));
      expect(response.messages!.single.text, "a");
      expect(response.messages!.single.actions.single.id, "Qm9x");
    });
  });
  group("openSheet", () {
    test("opens the chat sheet", () async {
      await withTrace((m) async {
        _registerDeps();
        final modal = CurrentModalValue();
        Core.register(modal);

        await SupportActor().openSheet(m);

        expect(modal.present, Modal.support);
      });
    });

    test("waits for another sheet to be dismissed first", () async {
      await withTrace((m) async {
        _registerDeps();
        final modal = CurrentModalValue();
        Core.register(modal);
        await modal.change(m, Modal.pause);

        final opening = SupportActor().openSheet(m);
        await Future<void>.delayed(Duration.zero);
        expect(modal.present, Modal.pause);

        await modal.change(m, null);
        await opening;
        expect(modal.present, Modal.support);
      });
    });

    test("does nothing while the chat is already on screen", () async {
      await withTrace((m) async {
        _registerDeps();
        when(Core.get<SupportUnreadActor>().isShowingChat).thenReturn(true);
        final modal = CurrentModalValue();
        Core.register(modal);

        await SupportActor().openSheet(m);

        expect(modal.present, isNull);
      });
    });
  });
}
