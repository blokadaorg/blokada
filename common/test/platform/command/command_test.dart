import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/onboard/domain/onboard.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/refresh/refresh.dart';
import 'package:common/src/platform/command/channel.pg.dart';
import 'package:common/src/platform/command/command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../tools.dart';

class _MockCommandOps extends Mock implements CommandOps {}

class _MockAccountStore extends Mock implements AccountStore {}

class _MockAccountRefreshStore extends Mock implements AccountRefreshStore {}

class _MockOnboardActor extends Mock implements OnboardActor {}

void main() {
  group('CommandStore', () {
    test('onRegister does not accept commands before bootstrap completes', () async {
      await withTrace((m) async {
        final ops = _MockCommandOps();
        when(() => ops.doCanAcceptCommands()).thenAnswer(ignore());

        final store = CommandStore(commandOps: ops);
        store.onRegister();

        verifyNever(() => ops.doCanAcceptCommands());
      });
    });

    test('acceptCommands flushes queued native commands once core bootstrap is ready', () async {
      await withTrace((m) async {
        final ops = _MockCommandOps();
        when(() => ops.doCanAcceptCommands()).thenAnswer(ignore());

        final store = CommandStore(commandOps: ops);
        store.onRegister();

        await store.acceptCommands(m);

        verify(() => ops.doCanAcceptCommands()).called(1);
      });
    });

    // Debug builds restore a test account from the command line through this
    // command, in both flavors, so it must reach the same AccountStore.restore
    // the Restore Account ID dialog uses.
    for (final flavor in [Flavor.v6, Flavor.family]) {
      test('restore command restores the account id in ${flavor.name}', () async {
        await withTrace((m) async {
          Core.act = ActScreenplay(ActScenario.test, flavor, PlatformType.android);

          final account = _MockAccountStore();
          when(() => account.restore(any(), any())).thenAnswer((_) async {});
          when(() => account.account).thenReturn(null);
          Core.register<AccountStore>(account);

          final refresh = _MockAccountRefreshStore();
          when(() => refresh.syncAccount(any(), any())).thenAnswer((_) async {});
          when(() => refresh.initialized).thenAnswer((_) async {});
          Core.register<AccountRefreshStore>(refresh);

          // Family has no onboarding intro; v6 marks it seen so it does not
          // come back on the next launch.
          final onboard = flavor == Flavor.v6 ? _MockOnboardActor() : null;
          if (onboard != null) {
            when(() => onboard.markIntroSeen(any())).thenAnswer((_) async {});
            Core.register<OnboardActor>(onboard);
          }

          await CommandStore().onCommandWithParam("restore", "abcdefghijkl", m);

          verify(() => account.restore("abcdefghijkl", any())).called(1);
          if (onboard != null) verify(() => onboard.markIntroSeen(any())).called(1);
        });
      });
    }

    // A restore sent at launch on a fresh install must not race the account
    // the app creates while it starts, or that account can replace it.
    test('restore command waits until the account is initialized', () async {
      await withTrace((m) async {
        final account = _MockAccountStore();
        when(() => account.restore(any(), any())).thenAnswer((_) async {});
        when(() => account.account).thenReturn(null);
        Core.register<AccountStore>(account);

        final initialized = Completer<void>();
        final refresh = _MockAccountRefreshStore();
        when(() => refresh.syncAccount(any(), any())).thenAnswer((_) async {});
        when(() => refresh.initialized).thenAnswer((_) => initialized.future);
        Core.register<AccountRefreshStore>(refresh);

        final onboard = _MockOnboardActor();
        when(() => onboard.markIntroSeen(any())).thenAnswer((_) async {});
        Core.register<OnboardActor>(onboard);

        final done = CommandStore().onCommandWithParam("restore", "abcdefghijkl", m);
        await Future<void>.delayed(Duration.zero);
        verifyNever(() => account.restore(any(), any()));

        initialized.complete();
        await done;
        verify(() => account.restore("abcdefghijkl", any())).called(1);
      });
    });
  });
}
