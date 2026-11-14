import 'package:common/src/app_variants/v6/module/home/home.dart';
import 'package:common/src/features/notification/domain/notification.dart';
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

WeeklyReportEvent _event() => WeeklyReportEvent(
  id: 'w',
  title: 't',
  body: 'b',
  type: WeeklyReportEventType.totalsDelta,
  icon: WeeklyReportIcon.trendUp,
  score: 10,
  generatedAt: DateTime(2026, 11, 1),
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

  group("busiestHourHeadline", () {
    test("findsThePeakHourCountingBackFromTheCurrentHour", () {
      final histogram = List.filled(24, 1);
      histogram[20] = 40; // three hours before the current one
      final headline = busiestHourHeadline(_stats(histogram), DateTime(2026, 11, 5, 15, 42))!;
      expect(headline.kind, HomeHeadlineKind.busiestHour);
      expect(headline.count, 40);
      expect(headline.hourStart, DateTime(2026, 11, 5, 12));
    });

    test("needsEnoughBlocks", () {
      final histogram = List.filled(24, 0);
      histogram[3] = 5;
      expect(busiestHourHeadline(_stats(histogram), DateTime(2026, 11, 5)), isNull);
      expect(busiestHourHeadline(UiStats.empty(), DateTime(2026, 11, 5)), isNull);
    });
  });

  group("topBlockedHeadline", () {
    test("needsADomainAndBlocks", () {
      expect(topBlockedHeadline('ads.example', 12)!.domain, 'ads.example');
      expect(topBlockedHeadline(null, 12), isNull);
      expect(topBlockedHeadline('ads.example', 0), isNull);
    });
  });

  group("pickHomeHeadline", () {
    final top = topBlockedHeadline('ads.example', 12)!;
    final busiest = HomeHeadline(kind: HomeHeadlineKind.busiestHour, score: 50, count: 9);
    final weekly = weeklyHeadline(_event());

    test("nothingToPickWithoutCandidates", () {
      expect(pickHomeHeadline([], previous: null, today: '2026-11-05'), isNull);
    });

    test("firstPickTakesTheBestCandidate", () {
      final result = pickHomeHeadline([weekly, busiest, top], previous: null, today: '2026-11-05')!;
      expect(result.headline.kind, HomeHeadlineKind.topBlocked);
      expect(result.pick.day, '2026-11-05');
      expect(result.pick.kind, HomeHeadlineKind.topBlocked);
    });

    test("keepsTodaysPickThroughTheDay", () {
      const previous = HomeHeadlinePick('2026-11-05', HomeHeadlineKind.weekly);
      final result = pickHomeHeadline(
        [busiest, top, weekly],
        previous: previous,
        today: '2026-11-05',
      )!;
      expect(result.headline.kind, HomeHeadlineKind.weekly);
      expect(result.pick, same(previous));
    });

    test("showsNoHeadlineWhileTodaysKindHasNoData", () {
      // The counter fills in rather than another kind for a moment.
      const previous = HomeHeadlinePick('2026-11-05', HomeHeadlineKind.topBlocked);
      expect(pickHomeHeadline([busiest], previous: previous, today: '2026-11-05'), isNull);
    });

    test("newDayAvoidsYesterdaysKind", () {
      const previous = HomeHeadlinePick('2026-11-04', HomeHeadlineKind.topBlocked);
      final result = pickHomeHeadline(
        [top, busiest, weekly],
        previous: previous,
        today: '2026-11-05',
      )!;
      expect(result.headline.kind, HomeHeadlineKind.busiestHour);
      expect(result.pick.kind, HomeHeadlineKind.busiestHour);
      expect(result.pick.day, '2026-11-05');
    });

    test("newDayRepeatsYesterdaysKindWhenItIsTheOnlyOne", () {
      const previous = HomeHeadlinePick('2026-11-04', HomeHeadlineKind.busiestHour);
      final result = pickHomeHeadline([busiest], previous: previous, today: '2026-11-05')!;
      expect(result.headline.kind, HomeHeadlineKind.busiestHour);
      expect(result.pick.day, '2026-11-05');
    });
  });

  group("HomeHeadlinePick", () {
    test("roundTripsAndRejectsUnknownKinds", () {
      const pick = HomeHeadlinePick('2026-11-05', HomeHeadlineKind.weekly);
      final back = HomeHeadlinePick.fromJson(pick.toJson())!;
      expect(back.day, pick.day);
      expect(back.kind, pick.kind);
      expect(HomeHeadlinePick.fromJson({'day': '2026-11-05', 'kind': 'gone'}), isNull);
    });
  });

  test("homeHeadlineDayUsesTheLocalDate", () {
    expect(homeHeadlineDay(DateTime(2026, 1, 2, 23, 59)), '2026-01-02');
  });
}
