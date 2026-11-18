import 'package:common/src/app_variants/v6/module/home/home.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:flutter_test/flutter_test.dart';

StoreSubscription _trial({
  required DateTime start,
  Duration length = const Duration(days: 7),
  String? offer = 'free_trial',
  String? owner = 'acc',
  String store = 'app_store',
}) => StoreSubscription(
  accessLevelId: 'premium',
  store: store,
  willRenew: true,
  expiresAt: start.add(length),
  customerUserId: owner,
  activatedAt: start,
  introOfferType: offer,
);

UiStats _stats(List<int> blocked) => UiStats(
  totalAllowed: 0,
  totalBlocked: 0,
  allowedHistogram: List.filled(blocked.length, 0),
  blockedHistogram: blocked,
  toplist: const [],
  avgDayTotal: 0,
  avgDayAllowed: 0,
  avgDayBlocked: 0,
  latestTimestamp: 0,
);

void main() {
  group("resolveTrialProgress", () {
    final start = DateTime(2026, 11, 3, 21, 30);

    test("countsCalendarDaysFromTheStart", () {
      final trial = resolveTrialProgress([_trial(start: start)], accountId: 'acc')!;
      expect(trial.length, 7);
      expect(trial.startedAt, start);
      // Same evening: day 1. Just after midnight: day 2, not at 21:30.
      expect(trial.dayOn(DateTime(2026, 11, 3, 23)), 1);
      expect(trial.dayOn(DateTime(2026, 11, 4, 0, 5)), 2);
      expect(trial.dayOn(DateTime(2026, 11, 5, 12)), 3);
    });

    test("clampsToTheTrialLength", () {
      final trial = resolveTrialProgress([_trial(start: start)], accountId: 'acc')!;
      expect(trial.dayOn(DateTime(2026, 11, 12)), 7);
      expect(trial.dayOn(DateTime(2026, 11, 1)), 1);
    });

    test("ignoresLevelsThatAreNotAnIntroFreeTrial", () {
      expect(resolveTrialProgress([_trial(start: start, offer: null)], accountId: 'acc'), isNull);
      expect(
        resolveTrialProgress([_trial(start: start, offer: 'pay_up_front')], accountId: 'acc'),
        isNull,
      );
      expect(resolveTrialProgress([], accountId: 'acc'), isNull);
    });

    test("ignoresWebLevels", () {
      expect(
        resolveTrialProgress([_trial(start: start, store: 'stripe')], accountId: 'acc'),
        isNull,
      );
      expect(
        resolveTrialProgress([_trial(start: start, store: 'play_store')], accountId: 'acc'),
        isNotNull,
      );
    });

    test("ignoresAnotherAccountsLevels", () {
      expect(
        resolveTrialProgress([_trial(start: start, owner: 'other')], accountId: 'acc'),
        isNull,
      );
      expect(
        resolveTrialProgress([_trial(start: start, owner: null)], accountId: 'acc'),
        isNotNull,
      );
    });

    test("ignoresImplausibleLengths", () {
      expect(
        resolveTrialProgress([
          _trial(start: start, length: const Duration(days: 365)),
        ], accountId: 'acc'),
        isNull,
      );
      expect(
        resolveTrialProgress([
          _trial(start: start, length: const Duration(hours: 2)),
        ], accountId: 'acc'),
        isNull,
      );
    });
  });

  group("trialBlockedSoFar", () {
    test("isAtLeastTheLast24Hours", () {
      final day = _stats(List.filled(24, 2)); // 48 in 24 h
      expect(trialBlockedSoFar(0, day), 48);
      expect(trialBlockedSoFar(500, day), 500);
      expect(trialBlockedSoFar(7, null), 7);
    });
  });
}
