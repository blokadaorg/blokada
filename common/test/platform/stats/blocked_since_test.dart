import 'package:common/src/platform/stats/api.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';

JsonStatsEndpoint _endpoint(Map<String, Map<int, double>> byAction) {
  return JsonStatsEndpoint(
    totalAllowed: "0",
    totalBlocked: "0",
    stats: JsonStats(
      metrics: [
        for (final entry in byAction.entries)
          JsonMetrics(
            tags: JsonTags(action: entry.key),
            dps: [
              for (final dp in entry.value.entries) JsonDps(timestamp: dp.key, value: dp.value),
            ],
          ),
      ],
    ),
  );
}

int _day(int day) => DateTime.utc(2026, 11, day).millisecondsSinceEpoch ~/ 1000;

void main() {
  group("sumBlockedSince", () {
    test("countsTheDayOfTheStartAndLaterOnlyBlocked", () {
      final endpoint = _endpoint({
        "blocked": {_day(1): 100, _day(2): 10, _day(3): 20, _day(4): 30},
        "allowed": {_day(2): 500, _day(3): 500},
        "fallthrough": {_day(3): 700},
      });

      // Started mid-day on the 2nd: the whole 2nd counts, the 1st does not.
      final since = DateTime.utc(2026, 11, 2, 15);
      expect(sumBlockedSince(endpoint, since), 60);
    });

    test("acceptsMillisecondTimestamps", () {
      final endpoint = _endpoint({
        "blocked": {_day(1) * 1000: 5, _day(2) * 1000: 7},
      });
      expect(sumBlockedSince(endpoint, DateTime.utc(2026, 11, 2)), 7);
    });

    test("isZeroWithoutData", () {
      expect(sumBlockedSince(_endpoint({}), DateTime.utc(2026, 11, 2)), 0);
    });
  });
}
