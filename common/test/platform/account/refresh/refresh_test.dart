import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/account/json.dart';
import 'package:common/platform/account/refresh/refresh.dart';
import 'package:common/platform/notification/notification.dart';
import 'package:common/platform/plus/plus.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../fixtures.dart';
import '../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<Scheduler>(),
  MockSpec<AccountStore>(),
  MockSpec<AccountRefreshStore>(),
  MockSpec<NotificationStore>(),
  MockSpec<StageStore>(),
  MockSpec<Persistence>(),
  MockSpec<PlusStore>(),
])
import 'refresh_test.mocks.dart';

void main() {
  group("store", () {
    test("willExpireAccountProperly", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<AccountStore>(AccountStore());
        Core.register<NotificationStore>(MockNotificationStore());
        Core.register<Persistence>(MockPersistence());
        Core.register<PlusStore>(MockPlusStore());

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
        await subject.syncAccount(account, m);
        expect(subject.expiration.status, AccountStatus.expiring);

        // Account already expired
        account = AccountState(
            Fixtures.accountId,
            JsonAccount(
                id: Fixtures.accountId,
                activeUntil: DateTime.now().toIso8601String(),
                type: AccountType.libre.name,
                active: false));
        await subject.syncAccount(account, m);
        expect(subject.expiration.status, AccountStatus.expired);

        // Account reset to Inactive
        await subject.markAsInactive(m);
        expect(subject.expiration.status, AccountStatus.inactive);
      });
    });

    test("willFetchAccountOnAppStartAndTimerFired", () async {
      await withTrace((m) async {
        final account = MockAccountStore();
        Core.register<AccountStore>(account);

        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<NotificationStore>(NotificationStore());
        Core.register<Persistence>(MockPersistence());

        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Load and refresh account on start
        await subject.init(m);
        verify(account.load(any)).called(1);
        verify(account.fetch(any)).called(1);

        // Imagine timer fired
        await subject.onTimerFired(m);
        verify(account.fetch(any)).called(1);
      });
    });

    test("willCreateAccountIfCouldNotFetch", () async {
      await withTrace((m) async {
        final account = MockAccountStore();
        when(account.load(any)).thenThrow(Exception("No existing account"));
        Core.register<AccountStore>(account);

        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<NotificationStore>(NotificationStore());
        Core.register<Persistence>(MockPersistence());

        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Load and refresh account on start
        await subject.init(m);

        verify(account.load(any)).called(1);
        verifyNever(account.fetch(any));
        verify(account.create(any)).called(1);
      });
    });

    test("maybeRefreshWillRespectLastRefreshTime", () async {
      await withTrace((m) async {
        Core.register<Scheduler>(MockScheduler());
        Core.register<NotificationStore>(MockNotificationStore());
        Core.register<Persistence>(MockPersistence());

        final route = StageRouteState.init().newTab(StageTab.home);
        final stage = MockStageStore();
        when(stage.route).thenReturn(route);
        Core.register<StageStore>(stage);

        final account = MockAccountStore();
        Core.register<AccountStore>(account);

        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Load and refresh account on start
        await subject.init(m);
        verify(account.fetch(any)).called(1);

        // Set last refresh as it never refreshed
        subject.lastRefresh = DateTime(0);

        await subject.onRouteChanged(route, m);
        verify(account.fetch(any)).called(1);
      });
    });
  });
}
