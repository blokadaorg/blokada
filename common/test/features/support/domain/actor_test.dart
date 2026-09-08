import 'dart:async';

import 'package:common/src/core/core.dart';
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
}
