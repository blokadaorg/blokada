import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/platform/command/command.dart';
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
  return api;
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

    test("is not set for local commands", () async {
      await withTrace((m) async {
        final api = _registerDeps();
        when(api.createSession(any, any, event: anyNamed("event")))
            .thenAnswer((_) async => _session("session-1"));
        final subject = SupportActor();
        final sending = subject.sendMessage("cc info", m);
        expect(subject.replyPending, false);
        await sending;
      });
    });

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
}
