import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/api.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../tools.dart';

class _MockStatsApi extends Mock implements StatsApi {}

class _MockDeviceStore extends Mock implements DeviceStore {}

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
  setUpAll(() => registerFallbackValue(Markers.testing));

  group("StatsStore.blockedSince", () {
    test("doesNotReuseThePreviousAccountsTwoWeeks", () async {
      await withTrace((m) async {
        final statsApi = _MockStatsApi();
        final device = _MockDeviceStore();
        final accountId = AccountId();
        Core.register<StatsApi>(statsApi);
        Core.register<DeviceStore>(device);
        Core.register<AccountId>(accountId);
        when(() => device.deviceAlias).thenReturn('Pixel');
        final answers = [
          _endpoint({
            "blocked": {_day(2): 10},
          }),
          _endpoint({
            "blocked": {_day(2): 99},
          }),
        ];
        when(
          () => statsApi.getStats("2w", "24h", 'Pixel', any()),
        ).thenAnswer((_) async => answers.removeAt(0));
        final store = StatsStore();
        final since = DateTime.utc(2026, 11, 1);

        await accountId.change(m, 'first');
        expect(await store.blockedSince(m, since), 10);
        await accountId.change(m, 'second');
        // Within the cache's lifetime, but another account.
        expect(await store.blockedSince(m, since), 99);
      });
    });
  });

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
