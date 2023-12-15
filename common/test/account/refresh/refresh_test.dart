import 'package:common/account/json.dart';
import 'package:common/account/refresh/refresh.dart';
import 'package:common/account/account.dart';
import 'package:common/notification/notification.dart';
import 'package:common/persistence/persistence.dart';
import 'package:common/plus/plus.dart';
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
  MockSpec<NotificationStore>(),
  MockSpec<StageStore>(),
  MockSpec<PersistenceService>(),
  MockSpec<PlusStore>(),
])
import 'refresh_test.mocks.dart';

void main() {
  group("store", () {
    test("willExpireAccountProperly", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());
        depend<TimerService>(MockTimerService());
        depend<AccountStore>(AccountStore());
        depend<NotificationStore>(MockNotificationStore());
        depend<PersistenceService>(MockPersistenceService());
        depend<PlusStore>(MockPlusStore());

        // Initial state
        final subject = AccountRefreshStore();
        mockAct(subject);
        expect(subject.expiration.status, AccountStatus.init);

        // Account will expire very soon
        AccountState account = AccountState(
            Fixtures.accountId,
            JsonAccount(
                id: Fixtures.accountId,
                activeUntil: DateTime.now()
                    .add(const Duration(seconds: 10))
                    .toIso8601String(),
                type: AccountType.cloud.name,
                active: true));
        await subject.syncAccount(trace, account);
        expect(subject.expiration.status, AccountStatus.expiring);

        // Account already expired
        account = AccountState(
            Fixtures.accountId,
            JsonAccount(
                id: Fixtures.accountId,
                activeUntil: DateTime.now().toIso8601String(),
                type: AccountType.libre.name,
                active: false));
        await subject.syncAccount(trace, account);
        expect(subject.expiration.status, AccountStatus.expired);

        // Account reset to Inactive
        await subject.markAsInactive(trace);
        expect(subject.expiration.status, AccountStatus.inactive);
      });
    });

    test("willFetchAccountOnAppStartAndTimerFired", () async {
      await withTrace((trace) async {
        final account = MockAccountStore();
        depend<AccountStore>(account);

        depend<StageStore>(MockStageStore());
        depend<TimerService>(MockTimerService());
        depend<NotificationStore>(NotificationStore());
        depend<PersistenceService>(MockPersistenceService());

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
        final account = MockAccountStore();
        when(account.load(any)).thenThrow(Exception("No existing account"));
        depend<AccountStore>(account);

        depend<StageStore>(MockStageStore());
        depend<TimerService>(MockTimerService());
        depend<NotificationStore>(NotificationStore());
        depend<PersistenceService>(MockPersistenceService());

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
        depend<TimerService>(MockTimerService());
        depend<NotificationStore>(MockNotificationStore());
        depend<PersistenceService>(MockPersistenceService());

        final route = StageRouteState.init().newTab(StageTab.home);
        final stage = MockStageStore();
        when(stage.route).thenReturn(route);
        depend<StageStore>(stage);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Load and refresh account on start
        await subject.init(trace);
        verify(account.fetch(any)).called(1);

        // Set last refresh as it never refreshed
        subject.lastRefresh = DateTime(0);

        await subject.onRouteChanged(trace, route);
        verify(account.fetch(any)).called(1);
      });
    });
  });
}
