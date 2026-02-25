import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/account/refresh/refresh.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../fixtures.dart';
import '../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<Scheduler>(),
  MockSpec<AccountStore>(),
  MockSpec<AccountRefreshStore>(),
  MockSpec<NotificationActor>(),
  MockSpec<StageStore>(),
  MockSpec<Persistence>(),
  MockSpec<PlusActor>(),
])
import 'refresh_test.mocks.dart';

void main() {
  group("store", () {
    test("willExpireAccountProperly", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<AccountStore>(AccountStore());
        Core.register<NotificationActor>(MockNotificationActor());
        Core.register<Persistence>(MockPersistence());
        Core.register<PlusActor>(MockPlusActor());

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
        Core.register<NotificationActor>(MockNotificationActor());
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
        Core.register<NotificationActor>(MockNotificationActor());
        Core.register<Persistence>(MockPersistence());

        // Initial state
        final subject = AccountRefreshStore();
        expect(subject.expiration.status, AccountStatus.init);

        // Load and refresh account on start
        await subject.init(m);

        verify(account.load(any)).called(1);
        verifyNever(account.fetch(any));
        verify(account.createAccount(any)).called(1);
      });
    });

    test("maybeRefreshWillRespectLastRefreshTime", () async {
      await withTrace((m) async {
        Core.register<Scheduler>(MockScheduler());
        Core.register<NotificationActor>(MockNotificationActor());
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

    test("onAccountExpiryEvent keeps scheduled delivery for future expiry", () async {
      await withTrace((m) async {
        final account = _TestAccountStore();
        final futureExpiry = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().toUtc().millisecondsSinceEpoch +
              const Duration(hours: 6).inMilliseconds,
          isUtc: true,
        );
        account.account = _accountState(
          activeUntil: futureExpiry,
          type: AccountType.cloud,
          active: true,
        );
        when(account.fetch(any)).thenAnswer((_) async {});
        Core.register<AccountStore>(account);

        final notification = MockNotificationActor();
        Core.register<NotificationActor>(notification);
        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<Persistence>(MockPersistence());
        Core.register<PlusActor>(MockPlusActor());

        final subject = AccountRefreshStore();
        await subject.onAccountExpiryEvent(m);

        final captured = verify(notification.show(
          NotificationId.accountExpired,
          any,
          when: captureAnyNamed('when'),
        )).captured;
        expect(captured, hasLength(1));

        final scheduledAt = captured.first as DateTime;
        expect(scheduledAt.toUtc(), futureExpiry.toUtc());
      });
    });

    test("onAccountExpiryEvent delivers immediate notification when already expired", () async {
      await withTrace((m) async {
        final account = _TestAccountStore();
        final expiredAt = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().toUtc().millisecondsSinceEpoch -
              const Duration(hours: 1).inMilliseconds,
          isUtc: true,
        );
        account.account = _accountState(
          activeUntil: expiredAt,
          type: AccountType.libre,
          active: false,
        );
        when(account.fetch(any)).thenAnswer((_) async {});
        Core.register<AccountStore>(account);

        final notification = MockNotificationActor();
        Core.register<NotificationActor>(notification);
        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<Persistence>(MockPersistence());
        Core.register<PlusActor>(MockPlusActor());

        final subject = AccountRefreshStore();
        await subject.onAccountExpiryEvent(m);

        verify(notification.show(NotificationId.accountExpired, any)).called(1);
        verifyNever(notification.show(
          NotificationId.accountExpired,
          any,
          when: anyNamed('when'),
        ));
      });
    });
  });

  group("resolveAccountExpirySchedule", () {
    final now = DateTime.utc(2026, 2, 24, 10, 0, 0);

    test("returns date when active_until is in the future", () {
      final scheduled = resolveAccountExpirySchedule("2026-02-24T12:00:00Z", now);
      expect(scheduled?.toUtc(), DateTime.utc(2026, 2, 24, 12, 0, 0));
    });

    test("returns null when active_until is now or in the past", () {
      expect(resolveAccountExpirySchedule("2026-02-24T10:00:00Z", now), isNull);
      expect(resolveAccountExpirySchedule("2026-02-24T09:59:59Z", now), isNull);
    });

    test("returns null when active_until is absent or invalid", () {
      expect(resolveAccountExpirySchedule(null, now), isNull);
      expect(resolveAccountExpirySchedule("", now), isNull);
      expect(resolveAccountExpirySchedule("invalid", now), isNull);
    });
  });
}

AccountState _accountState({
  required DateTime activeUntil,
  required AccountType type,
  required bool active,
}) {
  return AccountState(
    Fixtures.accountId,
    JsonAccount(
      id: Fixtures.accountId,
      activeUntil: activeUntil.toIso8601String(),
      type: type.name,
      active: active,
    ),
  );
}

class _TestAccountStore extends MockAccountStore {
  AccountState? _account;

  @override
  AccountState? get account => _account;

  @override
  set account(AccountState? value) {
    _account = value;
  }
}
