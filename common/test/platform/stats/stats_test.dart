import 'package:common/src/app_variants/family/module/stats/stats.dart';
import 'package:common/src/platform/stats/api.dart' as api;
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  group('computeStatsBaselines', () {
    test('merges fallthrough and allowed metrics into allowed totals', () {
      final dayStats = api.JsonStatsEndpoint.fromJson({
        'total_allowed': '8951585',
        'total_blocked': '951900',
        'stats': {
          'metrics': [
            {
              'tags': {'action': 'fallthrough'},
              'dps': [
                {'timestamp': '1760400000', 'value': 728},
                {'timestamp': '1760425200', 'value': 1461},
                {'timestamp': '1760428800', 'value': 169},
                {'timestamp': '1760349600', 'value': 1973},
                {'timestamp': '1760364000', 'value': 954},
                {'timestamp': '1760374800', 'value': 923},
                {'timestamp': '1760392800', 'value': 790},
                {'timestamp': '1760410800', 'value': 693},
                {'timestamp': '1760418000', 'value': 1426},
                {'timestamp': '1760421600', 'value': 1005},
                {'timestamp': '1760353200', 'value': 1030},
                {'timestamp': '1760367600', 'value': 772},
                {'timestamp': '1760385600', 'value': 847},
                {'timestamp': '1760389200', 'value': 1173},
                {'timestamp': '1760414400', 'value': 1348},
                {'timestamp': '1760356800', 'value': 1129},
                {'timestamp': '1760360400', 'value': 1138},
                {'timestamp': '1760378400', 'value': 670},
                {'timestamp': '1760403600', 'value': 476},
                {'timestamp': '1760407200', 'value': 736},
                {'timestamp': '1760346000', 'value': 1351},
                {'timestamp': '1760371200', 'value': 496},
                {'timestamp': '1760382000', 'value': 454},
                {'timestamp': '1760396400', 'value': 681},
              ],
            },
            {
              'tags': {'action': 'blocked'},
              'dps': [
                {'timestamp': '1760346000', 'value': 503},
                {'timestamp': '1760367600', 'value': 111},
                {'timestamp': '1760374800', 'value': 119},
                {'timestamp': '1760392800', 'value': 48},
                {'timestamp': '1760403600', 'value': 36},
                {'timestamp': '1760425200', 'value': 266},
                {'timestamp': '1760356800', 'value': 378},
                {'timestamp': '1760371200', 'value': 49},
                {'timestamp': '1760389200', 'value': 97},
                {'timestamp': '1760396400', 'value': 36},
                {'timestamp': '1760400000', 'value': 50},
                {'timestamp': '1760410800', 'value': 40},
                {'timestamp': '1760418000', 'value': 260},
                {'timestamp': '1760421600', 'value': 418},
                {'timestamp': '1760349600', 'value': 554},
                {'timestamp': '1760353200', 'value': 254},
                {'timestamp': '1760360400', 'value': 349},
                {'timestamp': '1760382000', 'value': 76},
                {'timestamp': '1760414400', 'value': 163},
                {'timestamp': '1760428800', 'value': 7},
                {'timestamp': '1760364000', 'value': 312},
                {'timestamp': '1760378400', 'value': 83},
                {'timestamp': '1760385600', 'value': 97},
                {'timestamp': '1760407200', 'value': 44},
              ],
            },
            {
              'tags': {'action': 'allowed'},
              'dps': [
                {'timestamp': '1760346000', 'value': 15},
                {'timestamp': '1760349600', 'value': 27},
                {'timestamp': '1760353200', 'value': 1},
                {'timestamp': '1760356800', 'value': 12},
                {'timestamp': '1760421600', 'value': 3},
                {'timestamp': '1760425200', 'value': 6},
                {'timestamp': '1760360400', 'value': 6},
                {'timestamp': '1760410800', 'value': 9},
                {'timestamp': '1760418000', 'value': 3},
              ],
            },
          ],
        },
      });

      final weekStats = api.JsonStatsEndpoint.fromJson({
        'total_allowed': '8951589',
        'total_blocked': '951900',
        'stats': {
          'metrics': [
            {
              'tags': {'action': 'fallthrough'},
              'dps': [
                {'timestamp': '1760400000', 'value': 8046},
                {'timestamp': '1759881600', 'value': 26592},
                {'timestamp': '1759968000', 'value': 29816},
                {'timestamp': '1760054400', 'value': 26603},
                {'timestamp': '1760140800', 'value': 25409},
                {'timestamp': '1760227200', 'value': 25167},
                {'timestamp': '1760313600', 'value': 26355},
              ],
            },
            {
              'tags': {'action': 'blocked'},
              'dps': [
                {'timestamp': '1760140800', 'value': 3804},
                {'timestamp': '1760227200', 'value': 2492},
                {'timestamp': '1760313600', 'value': 5170},
                {'timestamp': '1760400000', 'value': 1284},
                {'timestamp': '1759881600', 'value': 6922},
                {'timestamp': '1759968000', 'value': 7706},
                {'timestamp': '1760054400', 'value': 7412},
              ],
            },
            {
              'tags': {'action': 'allowed'},
              'dps': [
                {'timestamp': '1760054400', 'value': 133},
                {'timestamp': '1760140800', 'value': 12},
                {'timestamp': '1760227200', 'value': 49},
                {'timestamp': '1760313600', 'value': 103},
                {'timestamp': '1760400000', 'value': 21},
                {'timestamp': '1759881600', 'value': 84},
                {'timestamp': '1759968000', 'value': 198},
              ],
            },
          ],
        },
      });

      var maxDayTimestamp = 0;
      for (final metric in dayStats.stats.metrics) {
        for (final dp in metric.dps) {
          if (dp.timestamp > maxDayTimestamp) {
            maxDayTimestamp = dp.timestamp;
          }
        }
      }

      final referenceTime =
          DateTime.fromMillisecondsSinceEpoch((maxDayTimestamp + 3600) * 1000);

      final result = computeStatsBaselines(
        dayStats,
        weekStats,
        referenceTime: referenceTime,
      );

      final totalAllowedToday =
          result.allowedHistogram.fold<int>(0, (sum, value) => sum + value);
      final totalBlockedToday =
          result.blockedHistogram.fold<int>(0, (sum, value) => sum + value);

      const expectedAllowedHistogram = <int>[
        2000, 1031, 1141, 1144, 954, 772, 496, 923, 670, 454, 847, 1173,
        790, 681, 728, 476, 736, 702, 1348, 1429, 1008, 1467, 169, 0,
      ];
      const expectedBlockedHistogram = <int>[
        554, 254, 378, 349, 312, 111, 49, 119, 83, 76, 97, 97, 48, 36,
        50, 36, 44, 40, 163, 260, 418, 266, 7, 0,
      ];

      expect(result.allowedHistogram, equals(expectedAllowedHistogram));
      expect(result.blockedHistogram, equals(expectedBlockedHistogram));
      expect(totalAllowedToday, equals(21139));
      expect(totalBlockedToday, equals(3847));
      expect(result.avgDayAllowed, equals(53508));
      expect(result.avgDayBlocked, equals(11168));
      expect(result.avgDayTotal, equals(64676));

      final uiStats = UiStats(
        totalAllowed: result.totalAllowed,
        totalBlocked: result.totalBlocked,
        allowedHistogram: result.allowedHistogram,
        blockedHistogram: result.blockedHistogram,
        toplist: const [],
        avgDayAllowed: result.avgDayAllowed,
        avgDayBlocked: result.avgDayBlocked,
        avgDayTotal: result.avgDayTotal,
        latestTimestamp: result.latestTimestamp,
      );

      expect(
        uiStats.dayAllowedRatio,
        closeTo(39.50624205726246, 1e-9),
      );
      expect(
        uiStats.dayBlockedRatio,
        closeTo(34.44663323782235, 1e-9),
      );
    });

    test('handles weekly series with missing allowed days', () {
      const latestDay = 1700172800; // arbitrary epoch (seconds)

      final dayStats = api.JsonStatsEndpoint.fromJson({
        'total_allowed': '0',
        'total_blocked': '0',
        'stats': {
          'metrics': [
            {
              'tags': {'action': 'fallthrough'},
              'dps': [
                {'timestamp': '$latestDay', 'value': 50},
              ],
            },
            {
              'tags': {'action': 'allowed'},
              'dps': [
                {'timestamp': '$latestDay', 'value': 5},
              ],
            },
            {
              'tags': {'action': 'blocked'},
              'dps': [
                {'timestamp': '$latestDay', 'value': 2},
              ],
            },
          ],
        },
      });

      final weekStats = api.JsonStatsEndpoint.fromJson({
        'total_allowed': '0',
        'total_blocked': '0',
        'stats': {
          'metrics': [
            {
              'tags': {'action': 'fallthrough'},
              'dps': [
                {'timestamp': '${latestDay - 86400 * 2}', 'value': 100},
                {'timestamp': '${latestDay - 86400}', 'value': 120},
                {'timestamp': '$latestDay', 'value': 140},
              ],
            },
            {
              'tags': {'action': 'allowed'},
              'dps': [
                {'timestamp': '${latestDay - 86400}', 'value': 10},
                {'timestamp': '$latestDay', 'value': 20},
              ],
            },
            {
              'tags': {'action': 'blocked'},
              'dps': [
                {'timestamp': '${latestDay - 86400}', 'value': 5},
                {'timestamp': '$latestDay', 'value': 6},
              ],
            },
          ],
        },
      });

      final referenceTime =
          DateTime.fromMillisecondsSinceEpoch((latestDay + 3600) * 1000);

      final result = computeStatsBaselines(
        dayStats,
        weekStats,
        referenceTime: referenceTime,
      );

      expect(result.avgDayAllowed, equals(230));

      final uiStats = UiStats(
        totalAllowed: result.totalAllowed,
        totalBlocked: result.totalBlocked,
        allowedHistogram: result.allowedHistogram,
        blockedHistogram: result.blockedHistogram,
        toplist: const [],
        avgDayAllowed: result.avgDayAllowed,
        avgDayBlocked: result.avgDayBlocked,
        avgDayTotal: result.avgDayTotal,
        latestTimestamp: result.latestTimestamp,
      );

      expect(
        uiStats.dayAllowedRatio,
        closeTo(23.91304347826087, 1e-9),
      );
    });
  });

  group('sparkline series', () {
    test('builds 7d allowed series from rolling 2w stats', () {
      final raw = File('test/platform/stats/fixtures/stats_2w_iphone.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final endpoint = api.JsonStatsEndpoint.fromJson(decoded);

      final series = buildAllowedDailySeriesFromRollingStats(endpoint, days: 7);

      expect(series.values, equals([8572, 7713, 8404, 7561, 7877, 7826, 5926]));
      expect(series.values.length, equals(7));
      expect(series.step, equals(const Duration(days: 1)));
      expect(series.end.millisecondsSinceEpoch, equals(1765843200 * 1000));
    });

    test('pads missing days with zeros', () {
      final raw = File('test/platform/stats/fixtures/stats_2w_iphone.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final endpoint = api.JsonStatsEndpoint.fromJson(decoded);

      const missingTimestamp = 1765584000;
      for (final metric in endpoint.stats.metrics) {
        final isAllowed = metric.tags.action == "allowed" || metric.tags.action == "fallthrough";
        if (!isAllowed) continue;
        metric.dps = metric.dps.where((d) => d.timestamp != missingTimestamp).toList();
      }

      final series = buildAllowedDailySeriesFromRollingStats(endpoint, days: 7);

      expect(series.values, equals([8572, 7713, 8404, 0, 7877, 7826, 5926]));
      expect(series.values.length, equals(7));
      expect(series.end.millisecondsSinceEpoch, equals(1765843200 * 1000));
    });

    test('returns empty series when no allowed data exists', () {
      final raw = File('test/platform/stats/fixtures/stats_2w_iphone.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final endpoint = api.JsonStatsEndpoint.fromJson(decoded);

      endpoint.stats.metrics = endpoint.stats.metrics
          .where((metric) => metric.tags.action == "blocked")
          .toList();

      final series = buildAllowedDailySeriesFromRollingStats(endpoint, days: 7);

      expect(series.values, isEmpty);
      expect(series.end.millisecondsSinceEpoch, equals(0));
    });
  });
}
