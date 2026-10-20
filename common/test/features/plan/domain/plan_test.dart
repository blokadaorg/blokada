import 'package:common/src/core/core.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/features/plan/domain/plan.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 20);
final _until = DateTime.utc(2027, 2, 14);

JsonAccount _account({String? type, String? source, DateTime? until}) {
  final account = JsonAccount(
    id: 'testaccount01',
    activeUntil: until?.toIso8601String(),
    active: type != null && type != 'libre',
    type: type,
  );
  account.paymentSource = source;
  return account;
}

StoreSubscription _sub(
  String id, {
  String store = 'app_store',
  bool willRenew = true,
  DateTime? expiresAt,
}) =>
    StoreSubscription(accessLevelId: id, store: store, willRenew: willRenew, expiresAt: expiresAt);

void main() {
  group('resolvePlan', () {
    test('no account is no plan', () {
      expect(resolvePlan(account: null, subscriptions: [], now: _now), Plan.empty);
    });

    test('never paid is no plan, not expired', () {
      final plan = resolvePlan(
        account: _account(type: 'libre'),
        subscriptions: [],
        now: _now,
      );
      expect(plan.renewal, PlanRenewal.none);
      expect(plan.isActive, false);
    });

    test('paid before and lapsed is expired, keeps the store to fix billing', () {
      final plan = resolvePlan(
        account: _account(type: 'libre', source: 'google', until: DateTime.utc(2026, 9, 1)),
        subscriptions: [],
        now: _now,
      );
      expect(plan.renewal, PlanRenewal.expired);
      expect(plan.store, PlanStore.playStore);
    });

    test('store says auto-renew on: renews on the store expiry date', () {
      final expires = DateTime.utc(2027, 2, 13);
      final plan = resolvePlan(
        account: _account(type: 'cloud', source: 'apple', until: _until),
        subscriptions: [_sub('cloud', expiresAt: expires)],
        now: _now,
      );
      expect(
        plan,
        Plan(
          type: AccountType.cloud,
          renewal: PlanRenewal.renews,
          date: expires,
          store: PlanStore.appStore,
        ),
      );
    });

    test('store says auto-renew off: ends', () {
      final plan = resolvePlan(
        account: _account(type: 'plus', source: 'google', until: _until),
        subscriptions: [_sub('plus', store: 'play_store', willRenew: false, expiresAt: _until)],
        now: _now,
      );
      expect(plan.renewal, PlanRenewal.ends);
      expect(plan.store, PlanStore.playStore);
    });

    test('picks the access level of the account tier when several are active', () {
      final plan = resolvePlan(
        account: _account(type: 'plus', source: 'apple', until: _until),
        subscriptions: [
          _sub('cloud', willRenew: false, expiresAt: DateTime.utc(2026, 11, 1)),
          _sub('plus', willRenew: true, expiresAt: _until),
        ],
        now: _now,
      );
      expect(plan.renewal, PlanRenewal.renews);
      expect(plan.date, _until);
    });

    test('web purchase without a store level falls back to active until', () {
      final plan = resolvePlan(
        account: _account(type: 'cloud', source: 'paypal', until: _until),
        subscriptions: [],
        now: _now,
      );
      expect(
        plan,
        Plan(
          type: AccountType.cloud,
          renewal: PlanRenewal.activeUntil,
          date: _until,
          store: PlanStore.web,
        ),
      );
    });

    test('ticket source has nothing to manage', () {
      final plan = resolvePlan(
        account: _account(type: 'cloud', source: 'ticket', until: _until),
        subscriptions: [],
        now: _now,
      );
      expect(plan.renewal, PlanRenewal.activeUntil);
      expect(plan.store, PlanStore.none);
    });

    test('lifetime level without expiry falls back to active until', () {
      final plan = resolvePlan(
        account: _account(type: 'cloud', source: 'adapty', until: _until),
        subscriptions: [_sub('cloud', store: 'adapty')],
        now: _now,
      );
      expect(plan.renewal, PlanRenewal.activeUntil);
      expect(plan.date, _until);
    });

    test('the access level store wins over the payment source (cross-store)', () {
      final plan = resolvePlan(
        account: _account(type: 'cloud', source: 'google', until: _until),
        subscriptions: [_sub('cloud', store: 'app_store', expiresAt: _until)],
        now: _now,
      );
      expect(plan.store, PlanStore.appStore);
    });
  });

  group('resolvePlanStore', () {
    test('maps Adapty stores', () {
      expect(resolvePlanStore(adaptyStore: 'app_store'), PlanStore.appStore);
      expect(resolvePlanStore(adaptyStore: 'play_store'), PlanStore.playStore);
      expect(resolvePlanStore(adaptyStore: 'stripe'), PlanStore.web);
    });

    test('falls back to the payment source', () {
      expect(resolvePlanStore(adaptyStore: 'adapty', paymentSource: 'apple'), PlanStore.appStore);
      expect(resolvePlanStore(paymentSource: 'google'), PlanStore.playStore);
      expect(resolvePlanStore(paymentSource: 'stripe'), PlanStore.web);
      expect(resolvePlanStore(paymentSource: 'paypal'), PlanStore.web);
      expect(resolvePlanStore(paymentSource: 'ticket'), PlanStore.none);
      expect(resolvePlanStore(paymentSource: 'internal'), PlanStore.none);
      expect(resolvePlanStore(), PlanStore.none);
    });
  });

  group('manageLinkFor', () {
    test('uses the platform link when the plan is from this platform\'s store', () {
      expect(manageLinkFor(PlanStore.appStore, PlatformType.iOS), LinkId.manageSubscriptions);
      expect(manageLinkFor(PlanStore.playStore, PlatformType.android), LinkId.manageSubscriptions);
    });

    test('routes a plan bought in the other store to that store', () {
      expect(
        manageLinkFor(PlanStore.appStore, PlatformType.android),
        LinkId.manageSubscriptionsAppStore,
      );
      expect(
        manageLinkFor(PlanStore.playStore, PlatformType.iOS),
        LinkId.manageSubscriptionsPlayStore,
      );
    });

    test('web purchases go to the dashboard; nothing else has a link', () {
      expect(manageLinkFor(PlanStore.web, PlatformType.iOS), LinkId.manageSubscriptionsWeb);
      expect(manageLinkFor(PlanStore.none, PlatformType.iOS), isNull);
    });
  });
}
