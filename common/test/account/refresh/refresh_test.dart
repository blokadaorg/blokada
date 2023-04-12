import 'package:common/account/json.dart';
import 'package:common/account/refresh/refresh.dart';
import 'package:common/account/account.dart';
import 'package:common/notification/notification.dart';
import 'package:common/stage/stage.dart';
import 'package:common/timer/timer.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';

import '../../fixtures.dart';
@GenerateNiceMocks([
  MockSpec<TimerService>(),
  MockSpec<AccountStore>(),
  MockSpec<AccountRefreshStore>(),
  MockSpec<StageStore>(),
])
import 'refresh_test.mocks.dart';

void main() {
  group("store", () {
    test("willExpireAccountProperly", () async {
      await withTrace((trace) async {
        di.registerSingleton<TimerService>(MockTimerService());
        di.registerSingleton<AccountStore>(AccountStore());
        di.registerSingleton<NotificationStore>(NotificationStore());

        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Account will expire very soon
        AccountState account = AccountState(Fixtures.accountId, JsonAccount(
            id: Fixtures.accountId,
            activeUntil: DateTime.now()
                .add(const Duration(seconds: 10))
                .toIso8601String(),
            type: AccountType.cloud.name,
            active: true
        ));
        await subject.update(trace, account);
        expect(subject.expiration.status, AccountStatus.expiring);

        // Account already expired
        account = AccountState(Fixtures.accountId, JsonAccount(
            id: Fixtures.accountId,
            activeUntil: DateTime.now().toIso8601String(),
            type: AccountType.libre.name,
            active: false
        ));
        await subject.update(trace, account);
        expect(subject.expiration.status, AccountStatus.expired);

        // Account reset to Inactive
        await subject.markAsInactive(trace);
        expect(subject.expiration.status, AccountStatus.inactive);
      });
    });

    test("willFetchAccountOnAppStartAndTimerFired", () async {
      await withTrace((trace) async {
        di.registerSingleton<TimerService>(MockTimerService());
        di.registerSingleton<NotificationStore>(NotificationStore());

        final account = MockAccountStore();
        di.registerSingleton<AccountStore>(account);


        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Load and refresh account on start
        await subject.init(trace);
        verify(account.load(any)).called(1);
        verify(account.fetch(any)).called(1);

        // Imagine timer fired
        await subject.onTimerFired(trace);
        verify(account.fetch(any)).called(1);
      });
    });

    test("willCreateAccountIfCouldNotFetch", () async {
      await withTrace((trace) async {
        di.registerSingleton<TimerService>(MockTimerService());
        di.registerSingleton<NotificationStore>(NotificationStore());

        final account = MockAccountStore();
        when(account.load(any)).thenThrow(Exception("No existing account"));
        di.registerSingleton<AccountStore>(account);

        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Load and refresh account on start
        await subject.init(trace);

        verify(account.load(any)).called(1);
        verifyNever(account.fetch(any));
        verify(account.create(any)).called(1);
      });
    });

    test("maybeRefreshWillRespectLastRefreshTime", () async {
      await withTrace((trace) async {
        di.registerSingleton<TimerService>(MockTimerService());
        di.registerSingleton<NotificationStore>(NotificationStore());

        final account = MockAccountStore();
        di.registerSingleton<AccountStore>(account);

        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Load and refresh account on start
        await subject.init(trace);
        verify(account.fetch(any)).called(1);

        // Set last refresh as it never refreshed
        subject.lastRefresh = DateTime(0);

        // Should refresh once, and not the second time
        await subject.maybeRefresh(trace);
        verify(account.fetch(any)).called(1);

        await subject.maybeRefresh(trace);
        verifyNever(account.fetch(any));

        // Forceful refresh should do it anyway
        await subject.maybeRefresh(trace, force: true);
        verify(account.fetch(any)).called(1);
      });
    });

    test("willCountAccountUpgrades", () async {
      await withTrace((trace) async {
        di.registerSingleton<TimerService>(MockTimerService());
        di.registerSingleton<NotificationStore>(NotificationStore());

        final account = MockAccountStore();
        di.registerSingleton<AccountStore>(account);

        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Load and refresh account on start
        await subject.init(trace);
        verify(account.fetch(any)).called(1);

        // First provide inactive account
        await subject.update(trace, AccountState(Fixtures.accountId, JsonAccount(
            id: Fixtures.accountId,
            activeUntil: DateTime.now().toIso8601String(),
            type: AccountType.libre.name,
            active: false
        )));

        expect(subject.accountUpgrades, 0);

        // Providing active account should increase the counter
        await subject.update(trace, AccountState(Fixtures.accountId, JsonAccount(
            id: Fixtures.accountId,
            activeUntil: DateTime.now()
                .add(const Duration(seconds: 10))
                .toIso8601String(),
            type: AccountType.cloud.name,
            active: true
        )));

        expect(subject.accountUpgrades, 1);

        // Providing same account type should not increase the counter
        await subject.update(trace, AccountState(Fixtures.accountId, JsonAccount(
            id: Fixtures.accountId,
            activeUntil: DateTime.now()
                .add(const Duration(seconds: 100))
                .toIso8601String(),
            type: AccountType.cloud.name,
            active: true
        )));

        expect(subject.accountUpgrades, 1);

        // Providing a higher tier account should increase the counter
        await subject.update(trace, AccountState(Fixtures.accountId, JsonAccount(
            id: Fixtures.accountId,
            activeUntil: DateTime.now()
                .add(const Duration(seconds: 10))
                .toIso8601String(),
            type: AccountType.plus.name,
            active: true
        )));

        expect(subject.accountUpgrades, 2);
      });
    });
  });

  group("binder", () {
    test("onRetryInit", () async {
      await withTrace((trace) async {
        di.registerSingleton<StageStore>(StageStore());
        di.registerSingleton<AccountStore>(MockAccountStore());
        di.registerSingleton<TimerService>(MockTimerService());

        final store = MockAccountRefreshStore();
        int callCounter = 0;
        when(store.init(any)).thenAnswer((_) async {
          if (callCounter++ < 2) {
            throw Exception("Failed to init");
          }
        });
        di.registerSingleton<AccountRefreshStore>(store);

        // Initial state
        final subject = AccountRefreshBinder.forTesting();

        // Do init (should retry on failing init)
        await subject.onRetryInit();
        verify(store.init(any)).called(3);
      });
    });

    test("onAccountUpgraded", () async {
      await withTrace((trace) async {
        di.registerSingleton<AccountStore>(MockAccountStore());
        di.registerSingleton<TimerService>(MockTimerService());

        final stage = MockStageStore();
        di.registerSingleton<StageStore>(stage);

        final store = AccountRefreshStore();
        di.registerSingleton<AccountRefreshStore>(store);

        final subject = AccountRefreshBinder.forTesting();
        verifyNever(stage.showModalNow(any, any));

        store.accountUpgrades = 1;
        verify(stage.showModalNow(any, any)).called(1);

        store.accountUpgrades = 1;
        verifyNever(stage.showModalNow(any, any));

        store.accountUpgrades = 2;
        verify(stage.showModalNow(any, any)).called(1);
      });
    });
  });
}
