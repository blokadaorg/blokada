import 'dart:convert';

import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/account/refresh/json.dart';
import 'package:common/src/platform/account/refresh/refresh.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
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
                activeUntil: DateTime.now().add(const Duration(seconds: 10)).toIso8601String(),
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
        final account = _TestAccountStore();
        when(account.load(any)).thenAnswer((_) async {
          account.account = _accountState(
            activeUntil: DateTime.now().add(const Duration(days: 3)),
            type: AccountType.plus,
            active: true,
          );
        });
        when(account.fetch(any)).thenAnswer((_) async {});
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

    test("willClearStaleRefreshMetadataWhenCreatingNewAccount", () async {
      await withTrace((m) async {
        final account = _TestAccountStore();
        when(account.load(any)).thenThrow(Exception("No existing account"));
        when(account.createAccount(any)).thenAnswer((_) async {
          account.account = _accountState(
            activeUntil: DateTime.now(),
            type: AccountType.libre,
            active: false,
          );
        });
        Core.register<AccountStore>(account);

        final stage = MockStageStore();
        final persistence = MockPersistence();
        when(persistence.load(any, "account:refresh")).thenAnswer(
          (_) async => jsonEncode({
            "previousAccountType": AccountType.plus.toSimpleString(),
            "seenExpiredDialog": false,
          }),
        );

        Core.register<StageStore>(stage);
        Core.register<Scheduler>(MockScheduler());
        Core.register<NotificationActor>(MockNotificationActor());
        Core.register<Persistence>(persistence);
        Core.register<PlusActor>(MockPlusActor());

        final subject = AccountRefreshStore();
        await subject.init(m);

        verify(account.load(any)).called(1);
        verify(account.createAccount(any)).called(1);
        verifyNever(account.fetch(any));
        verify(persistence.delete(any, "account:refresh")).called(1);
        verifyNever(persistence.load(any, "account:refresh"));
        verifyNever(stage.showModal(StageModal.accountExpired, any));
      });
    });

    test("willCreateNewAccountWhenCachedAccountFetchReturns400", () async {
      await _expectInvalidCachedAccountCreatesFreshAccount(400);
    });

    test("willCreateNewAccountWhenCachedAccountFetchReturns404", () async {
      await _expectInvalidCachedAccountCreatesFreshAccount(404);
    });

    test("willReusePreloadedCachedAccountIfRefreshFails", () async {
      await withTrace((m) async {
        final account = MockAccountStore();
        final cachedAccount = AccountState(
          Fixtures.accountId,
          JsonAccount(
            id: Fixtures.accountId,
            activeUntil: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
            type: AccountType.plus.name,
            active: true,
          ),
        );
        when(account.account).thenReturn(cachedAccount);
        when(account.fetch(any)).thenThrow(Exception("offline"));
        Core.register<AccountStore>(account);

        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<NotificationActor>(MockNotificationActor());
        Core.register<Persistence>(MockPersistence());

        final subject = AccountRefreshStore();
        await subject.init(m);

        verifyNever(account.load(any));
        verify(account.fetch(any)).called(1);
        verifyNever(account.createAccount(any));
        expect(subject.expiration.status, AccountStatus.active);
      });
    });

    test("willKeepCachedAccountWhenFetchReturns500", () async {
      await withTrace((m) async {
        final account = _TestAccountStore();
        account.account = _accountState(
          activeUntil: DateTime.now().add(const Duration(days: 3)),
          type: AccountType.plus,
          active: true,
        );
        when(account.fetch(any)).thenThrow(HttpCodeException(500, "server"));
        Core.register<AccountStore>(account);

        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<NotificationActor>(MockNotificationActor());
        Core.register<Persistence>(MockPersistence());

        final subject = AccountRefreshStore();
        await subject.init(m);

        verifyNever(account.load(any));
        verify(account.fetch(any)).called(1);
        verifyNever(account.createAccount(any));
        expect(account.account?.id, Fixtures.accountId);
        expect(subject.expiration.status, AccountStatus.active);
      });
    });

    test("willKeepPersistedCachedAccountIfRefreshFails", () async {
      await withTrace((m) async {
        final account = _TestAccountStore();
        when(account.load(any)).thenAnswer((_) async {
          account.account = _accountState(
            activeUntil: DateTime.now().add(const Duration(days: 3)),
            type: AccountType.plus,
            active: true,
          );
        });
        when(account.fetch(any)).thenThrow(Exception("offline"));
        Core.register<AccountStore>(account);

        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<NotificationActor>(MockNotificationActor());
        Core.register<Persistence>(MockPersistence());

        final subject = AccountRefreshStore();
        await subject.init(m);

        verify(account.load(any)).called(1);
        verify(account.fetch(any)).called(1);
        verifyNever(account.createAccount(any));
        expect(account.account?.id, Fixtures.accountId);
        expect(subject.expiration.status, AccountStatus.active);
      });
    });

    test("willKeepLoadedAccountIfLoadThrowsAfterPopulatingState", () async {
      await withTrace((m) async {
        final account = _TestAccountStore();
        when(account.load(any)).thenAnswer((_) async {
          account.account = _accountState(
            activeUntil: DateTime.now().add(const Duration(days: 3)),
            type: AccountType.plus,
            active: true,
          );
          throw Exception("device refresh failed");
        });
        when(account.fetch(any)).thenAnswer((_) async {});
        Core.register<AccountStore>(account);

        Core.register<StageStore>(MockStageStore());
        Core.register<Scheduler>(MockScheduler());
        Core.register<NotificationActor>(MockNotificationActor());
        Core.register<Persistence>(MockPersistence());

        final subject = AccountRefreshStore();
        await subject.init(m);

        verify(account.load(any)).called(1);
        verify(account.fetch(any)).called(1);
        verifyNever(account.createAccount(any));
        expect(account.account?.id, Fixtures.accountId);
        expect(subject.expiration.status, AccountStatus.active);
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

        final account = _TestAccountStore();
        when(account.load(any)).thenAnswer((_) async {
          account.account = _accountState(
            activeUntil: DateTime.now().add(const Duration(days: 3)),
            type: AccountType.plus,
            active: true,
          );
        });
        when(account.fetch(any)).thenAnswer((_) async {});
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
          DateTime.now().toUtc().millisecondsSinceEpoch + const Duration(hours: 6).inMilliseconds,
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
          DateTime.now().toUtc().millisecondsSinceEpoch - const Duration(hours: 1).inMilliseconds,
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

    test("onAccountExpiryEvent notifies once for repeated events", () async {
      await withTrace((m) async {
        final subject = _expirySubject(expiredAt: _agoUtc(const Duration(hours: 1)));

        await subject.store.onAccountExpiryEvent(m);
        await subject.store.onAccountExpiryEvent(m);

        verify(subject.notification.show(NotificationId.accountExpired, any)).called(1);
      });
    });

    // The backend restamps active_until to now on every repeat webhook for a
    // lapsed account, so each event carries a different expiry string. This is
    // the actual reported bug.
    test("onAccountExpiryEvent does not renotify when active_until is restamped", () async {
      await withTrace((m) async {
        final subject = _expirySubject(expiredAt: _agoUtc(const Duration(hours: 2)));

        await subject.store.onAccountExpiryEvent(m);
        subject.account.account = _accountState(
          activeUntil: _agoUtc(const Duration(seconds: 1)),
          type: AccountType.libre,
          active: false,
        );
        await subject.store.onAccountExpiryEvent(m);

        verify(subject.notification.show(NotificationId.accountExpired, any)).called(1);
      });
    });

    test(
      "onAccountExpiryEvent skips the immediate notification after the scheduled one fired",
      () async {
        await withTrace((m) async {
          final subject = _expirySubject(
            expiredAt: _agoUtc(const Duration(minutes: 5)),
            metadata: {"expiryScheduledFor": _agoUtc(const Duration(minutes: 5)).toIso8601String()},
          );

          await subject.store.onAccountExpiryEvent(m);

          verifyNever(subject.notification.show(NotificationId.accountExpired, any));
        });
      },
    );

    test("onAccountExpiryEvent notifies again once the cooldown elapsed", () async {
      await withTrace((m) async {
        final subject = _expirySubject(
          expiredAt: _agoUtc(const Duration(days: 30)),
          metadata: {
            "expiryNotifiedAt": _agoUtc(const Duration(days: 8)).toIso8601String(),
            "expiryScheduledFor": _agoUtc(const Duration(days: 30)).toIso8601String(),
          },
        );

        await subject.store.onAccountExpiryEvent(m);

        verify(subject.notification.show(NotificationId.accountExpired, any)).called(1);
      });
    });

    test("onAccountExpiryEvent notifies again after a renewal and a later expiry", () async {
      await withTrace((m) async {
        final subject = _expirySubject(expiredAt: _agoUtc(const Duration(hours: 1)));

        await subject.store.onAccountExpiryEvent(m);

        // Renewed: a future expiry is scheduled, which ends the lapse.
        subject.account.account = _accountState(
          activeUntil: DateTime.now().toUtc().add(const Duration(days: 30)),
          type: AccountType.plus,
          active: true,
        );
        await subject.store.onAccountExpiryEvent(m);

        // Lapsed again.
        subject.account.account = _accountState(
          activeUntil: _agoUtc(const Duration(minutes: 1)),
          type: AccountType.libre,
          active: false,
        );
        await subject.store.onAccountExpiryEvent(m);

        verify(subject.notification.show(NotificationId.accountExpired, any)).called(2);
      });
    });

    test("onAccountExpiryEvent does not notify when active_until is missing", () async {
      await withTrace((m) async {
        final subject = _expirySubject(expiredAt: _agoUtc(const Duration(hours: 1)));
        subject.account.account = AccountState(
          Fixtures.accountId,
          JsonAccount(
            id: Fixtures.accountId,
            activeUntil: null,
            type: AccountType.libre.name,
            active: false,
          ),
        );

        await subject.store.onAccountExpiryEvent(m);

        verifyNever(subject.notification.show(NotificationId.accountExpired, any));
      });
    });

    test("syncAccount records the expiry the notification was scheduled for", () async {
      await withTrace((m) async {
        final expiry = DateTime.now().toUtc().add(const Duration(days: 3));
        final subject = _expirySubject(expiredAt: expiry, type: AccountType.plus, active: true);

        await subject.store.syncAccount(subject.account.account, m);

        final saved = verify(
          subject.persistence.save(any, "account:refresh", captureAny),
        ).captured.map((json) => jsonDecode(json as String) as Map<String, dynamic>).toList();
        expect(saved, isNotEmpty);
        expect(saved.last["expiryScheduledFor"], expiry.toIso8601String());
      });
    });
  });

  group("JsonAccRefreshMeta", () {
    test("round trips the expiry guard fields", () {
      final meta = JsonAccRefreshMeta(
        previousAccountType: AccountType.plus,
        seenExpiredDialog: true,
        expiryNotifiedAt: "2026-02-23T11:30:00.000Z",
        expiryScheduledFor: "2026-02-20T11:30:00.000Z",
      );

      final decoded = JsonAccRefreshMeta.fromJson(jsonDecode(jsonEncode(meta.toJson())));

      expect(decoded.previousAccountType, AccountType.plus);
      expect(decoded.seenExpiredDialog, true);
      expect(decoded.expiryNotifiedAt, "2026-02-23T11:30:00.000Z");
      expect(decoded.expiryScheduledFor, "2026-02-20T11:30:00.000Z");
    });

    test("reads metadata that predates the expiry guard fields", () {
      final decoded = JsonAccRefreshMeta.fromJson({
        "previousAccountType": AccountType.plus.toSimpleString(),
        "seenExpiredDialog": true,
      });

      expect(decoded.expiryNotifiedAt, isNull);
      expect(decoded.expiryScheduledFor, isNull);
    });

    test("treats a non-string stored timestamp as absent", () {
      final decoded = JsonAccRefreshMeta.fromJson({"expiryNotifiedAt": 42});

      expect(decoded.expiryNotifiedAt, isNull);
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
  String id = Fixtures.accountId,
  required DateTime activeUntil,
  required AccountType type,
  required bool active,
}) {
  return AccountState(
    id,
    JsonAccount(
      id: id,
      activeUntil: activeUntil.toIso8601String(),
      type: type.name,
      active: active,
    ),
  );
}

Future<void> _expectInvalidCachedAccountCreatesFreshAccount(int code) async {
  await withTrace((m) async {
    const oldAccountId = "oldaccountaa";
    const newAccountId = "freshaccount";
    final account = _TestAccountStore();
    account.account = _accountState(
      id: oldAccountId,
      activeUntil: DateTime.now().add(const Duration(days: 3)),
      type: AccountType.plus,
      active: true,
    );
    when(account.fetch(any)).thenThrow(HttpCodeException(code, "invalid account"));
    when(account.createAccount(any)).thenAnswer((_) async {
      account.account = _accountState(
        id: newAccountId,
        activeUntil: DateTime.now(),
        type: AccountType.libre,
        active: false,
      );
    });
    Core.register<AccountStore>(account);

    final stage = MockStageStore();
    final persistence = MockPersistence();
    final securePersistence = MockPersistence();
    when(persistence.load(any, "account:refresh")).thenAnswer(
      (_) async => jsonEncode({
        "previousAccountType": AccountType.plus.toSimpleString(),
        "seenExpiredDialog": false,
      }),
    );

    Core.register<StageStore>(stage);
    Core.register<Scheduler>(MockScheduler());
    Core.register<NotificationActor>(MockNotificationActor());
    Core.register<Persistence>(persistence);
    Core.register<Persistence>(securePersistence, tag: Persistence.secure);
    Core.register<PlusActor>(MockPlusActor());

    final subject = AccountRefreshStore();
    await subject.init(m);

    verifyNever(account.load(any));
    verify(account.fetch(any)).called(1);
    verify(account.createAccount(any)).called(1);
    verify(securePersistence.delete(any, "account:jsonAccount", isBackup: true)).called(1);
    verify(persistence.delete(any, "account:refresh")).called(1);
    verifyNever(persistence.load(any, "account:refresh"));
    verifyNever(stage.showModal(StageModal.accountExpired, any));
    expect(account.account?.id, newAccountId);
    expect(account.account?.type, AccountType.libre);
  });
}

DateTime _agoUtc(Duration ago) => DateTime.now().toUtc().subtract(ago);

class _ExpirySubject {
  final AccountRefreshStore store;
  final _TestAccountStore account;
  final MockNotificationActor notification;
  final MockPersistence persistence;

  _ExpirySubject(this.store, this.account, this.notification, this.persistence);
}

// A store wired for the expiry-notification paths, with persistence that
// answers with the given stored metadata.
_ExpirySubject _expirySubject({
  required DateTime expiredAt,
  AccountType type = AccountType.libre,
  bool active = false,
  Map<String, dynamic>? metadata,
}) {
  final account = _TestAccountStore();
  account.account = _accountState(activeUntil: expiredAt, type: type, active: active);
  when(account.fetch(any)).thenAnswer((_) async {});
  Core.register<AccountStore>(account);

  final notification = MockNotificationActor();
  final persistence = MockPersistence();
  when(
    persistence.load(any, "account:refresh"),
  ).thenAnswer((_) async => metadata == null ? null : jsonEncode(metadata));
  Core.register<NotificationActor>(notification);
  Core.register<Persistence>(persistence);
  Core.register<StageStore>(MockStageStore());
  Core.register<Scheduler>(MockScheduler());
  Core.register<PlusActor>(MockPlusActor());

  return _ExpirySubject(AccountRefreshStore(), account, notification, persistence);
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
