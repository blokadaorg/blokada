import 'package:common/src/core/core.dart';
import 'package:common/src/features/stats/ui/activity_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Local times, as the list shows them: 23 Oct 2026, 14:00.
  final now = DateTime(2026, 10, 23, 14);

  group('activityPeriodOf', () {
    test('the last hour is just now', () {
      expect(activityPeriodOf(now, now), ActivityPeriod.justNow);
      expect(activityPeriodOf(DateTime(2026, 10, 23, 13, 1), now), ActivityPeriod.justNow);
      expect(activityPeriodOf(DateTime(2026, 10, 23, 13), now), ActivityPeriod.earlierToday);
    });

    test('earlier today goes back to midnight', () {
      expect(activityPeriodOf(DateTime(2026, 10, 23, 8), now), ActivityPeriod.earlierToday);
      expect(activityPeriodOf(DateTime(2026, 10, 23), now), ActivityPeriod.earlierToday);
    });

    test('just before midnight is yesterday', () {
      final atTwo = DateTime(2026, 10, 23, 2);
      expect(activityPeriodOf(DateTime(2026, 10, 23, 0, 0, 1), atTwo), ActivityPeriod.earlierToday);
      expect(activityPeriodOf(DateTime(2026, 10, 22, 23, 59, 59), atTwo), ActivityPeriod.yesterday);
      expect(activityPeriodOf(DateTime(2026, 10, 22), atTwo), ActivityPeriod.yesterday);
    });

    test('just now wins over yesterday right after midnight', () {
      final afterMidnight = DateTime(2026, 10, 23, 0, 10);
      expect(
        activityPeriodOf(DateTime(2026, 10, 22, 23, 50), afterMidnight),
        ActivityPeriod.justNow,
      );
      expect(activityPeriodOf(DateTime(2026, 10, 22, 22), afterMidnight), ActivityPeriod.yesterday);
    });

    test('before yesterday is older', () {
      expect(activityPeriodOf(DateTime(2026, 10, 21, 23, 59), now), ActivityPeriod.older);
      expect(activityPeriodOf(DateTime(2025, 10, 22), now), ActivityPeriod.older);
    });

    test('yesterday crosses month and year ends', () {
      expect(
        activityPeriodOf(DateTime(2026, 9, 30, 12), DateTime(2026, 10, 1, 12)),
        ActivityPeriod.yesterday,
      );
      expect(
        activityPeriodOf(DateTime(2025, 12, 31, 12), DateTime(2026, 1, 1, 12)),
        ActivityPeriod.yesterday,
      );
    });

    test('UTC timestamps are grouped by the local day', () {
      final at = DateTime(2026, 10, 22, 23, 30);
      expect(activityPeriodOf(at.toUtc(), DateTime(2026, 10, 23, 2)), ActivityPeriod.yesterday);
    });
  });

  group('activityGroupLabel', () {
    test('names the recent groups', () {
      expect(activityGroupLabel(now, now, "en"), "activity group just now".i18n);
      expect(
        activityGroupLabel(DateTime(2026, 10, 23, 9), now, "en"),
        "activity group earlier today".i18n,
      );
      expect(
        activityGroupLabel(DateTime(2026, 10, 22, 9), now, "en"),
        "activity group yesterday".i18n,
      );
    });

    test('older days show the date, with the year only if not this one', () {
      expect(activityGroupLabel(DateTime(2026, 10, 20, 9), now, "en_US"), "Tue, Oct 20");
      expect(activityGroupLabel(DateTime(2025, 10, 20, 9), now, "en_US"), "Mon, Oct 20, 2025");
    });

    test('a locale without date data falls back to English', () {
      expect(activityGroupLabel(DateTime(2026, 10, 20, 9), now, "xx"), "Tue, Oct 20");
    });
  });

  test('activityGroupLabels labels each time like activityGroupLabel', () {
    final times = [
      DateTime(2026, 10, 23, 13, 30),
      DateTime(2026, 10, 23, 9),
      DateTime(2026, 10, 22, 9),
      DateTime(2026, 10, 20, 18),
      DateTime(2026, 10, 20, 9),
      DateTime(2025, 10, 20, 9),
    ];
    expect(activityGroupLabels(times, now, "en_US"), [
      for (final at in times) activityGroupLabel(at, now, "en_US"),
    ]);
  });
}
