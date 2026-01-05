import 'dart:convert';
import 'dart:io';

import 'package:common/platform/stats/api.dart' as api;
import 'package:common/platform/stats/delta_store.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:common/family/module/stats/stats.dart' as family_stats;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('counter deltas from rolling 2w stats', () {
    test('computes weekly counters (7d vs previous 7d) from fixture', () {
      final raw = File('test/platform/stats/fixtures/stats_2w_iphone.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final endpoint = api.JsonStatsEndpoint.fromJson(decoded);

      final weekly = buildPeriodCountersFromRollingStats(endpoint, days: 7);
      expect(weekly.hasComparison, isTrue);

      final delta = computeCounterDelta(
        previous: weekly.previous,
        current: weekly.current,
        hasComparison: weekly.hasComparison,
      );

      // Expected from fixture (percent change relative to previous window's same metric):
      // - Previous totals: allowed=53,970 (allowed+fallthrough), blocked=7,548 => total=61,518
      // - Current totals:  allowed=53,879, blocked=16,207
      // - Blocked delta: (16,207 - 7,548) / 7,548 * 100 = 114.7... => 115% (rounded)
      // - Allowed delta: (53,879 - 53,970) / 53,970 * 100 = -0.16... => 0% (rounded)
      expect(delta.blockedPercent, equals(115));
      expect(delta.allowedPercent, equals(0));
      expect(delta.hasComparison, isTrue);
    });

    test('computes daily counters (last 24h vs previous 24h) from fixture', () {
      final raw = File('test/platform/stats/fixtures/stats_48h_iphone.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final endpoint = api.JsonStatsEndpoint.fromJson(decoded);

      // Anchor at the last datapoint + 1h, matching StatsStore hour truncation.
      var latestTimestamp = 0;
      for (final metric in endpoint.stats.metrics) {
        for (final dp in metric.dps) {
          if (dp.timestamp > latestTimestamp) latestTimestamp = dp.timestamp;
        }
      }
      final referenceTime =
          DateTime.fromMillisecondsSinceEpoch((latestTimestamp + 3600) * 1000, isUtc: true);

      final daily = buildHourlyPeriodCountersFromRollingStats(
        endpoint,
        hours: 24,
        referenceTime: referenceTime,
      );
      expect(daily.hasComparison, isTrue);

      final delta = computeCounterDelta(
        previous: daily.previous,
        current: daily.current,
        hasComparison: daily.hasComparison,
      );

      // Expected from fixture (percent change relative to previous window's same metric):
      // - Allowed prev=4,857, curr=7,047 => +45% (rounded)
      // - Blocked prev=2,021, curr=2,610 => +29% (rounded)
      expect(delta.allowedPercent, equals(45));
      expect(delta.blockedPercent, equals(29));
      expect(delta.hasComparison, isTrue);
    });

    test('includes current hour counters for new user fixture', () {
      final raw = File('test/platform/stats/fixtures/stats_48h_new_user.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final endpoint = api.JsonStatsEndpoint.fromJson(decoded);

      var latestTimestamp = 0;
      for (final metric in endpoint.stats.metrics) {
        for (final dp in metric.dps) {
          if (dp.timestamp > latestTimestamp) latestTimestamp = dp.timestamp;
        }
      }

      final referenceTime =
          DateTime.fromMillisecondsSinceEpoch((latestTimestamp + 1800) * 1000, isUtc: true);

      final daily = buildHourlyPeriodCountersFromRollingStats(
        endpoint,
        hours: 24,
        referenceTime: referenceTime,
      );

      expect(daily.current.allowed, equals(17));
      expect(daily.current.blocked, equals(10));
      expect(daily.current.total, equals(27));
      expect(daily.previous.allowed, equals(0));
      expect(daily.previous.blocked, equals(0));
      expect(daily.previous.total, equals(0));
      expect(daily.hasComparison, isFalse);
    });

    test('returns 0 when baseline is zero', () {
      final delta = computeCounterDelta(
        previous: const StatsCounters(allowed: 0, blocked: 0, total: 0),
        current: const StatsCounters(allowed: 10, blocked: 5, total: 15),
        hasComparison: true,
      );

      expect(delta.allowedPercent, equals(0));
      expect(delta.blockedPercent, equals(0));
      expect(delta.hasComparison, isTrue);
    });

    test('hasComparison false yields empty delta', () {
      final delta = computeCounterDelta(
        previous: const StatsCounters(allowed: 1, blocked: 1, total: 2),
        current: const StatsCounters(allowed: 2, blocked: 2, total: 4),
        hasComparison: false,
      );

      expect(delta.allowedPercent, equals(0));
      expect(delta.blockedPercent, equals(0));
      expect(delta.hasComparison, isFalse);
    });
  });

  group('activity circles data window', () {
    test('computeStatsBaselines uses last 24h even when day endpoint spans 48h', () {
      final raw48h = File('test/platform/stats/fixtures/stats_48h_iphone.json').readAsStringSync();
      final decoded48h = jsonDecode(raw48h) as Map<String, dynamic>;
      final hourly48h = api.JsonStatsEndpoint.fromJson(decoded48h);

      final raw2w = File('test/platform/stats/fixtures/stats_2w_iphone.json').readAsStringSync();
      final decoded2w = jsonDecode(raw2w) as Map<String, dynamic>;
      final daily2w = api.JsonStatsEndpoint.fromJson(decoded2w);

      var latestTimestamp = 0;
      for (final metric in hourly48h.stats.metrics) {
        for (final dp in metric.dps) {
          if (dp.timestamp > latestTimestamp) latestTimestamp = dp.timestamp;
        }
      }
      final referenceTime =
          DateTime.fromMillisecondsSinceEpoch((latestTimestamp + 3600) * 1000, isUtc: true);

      final baselines = computeStatsBaselines(hourly48h, daily2w, referenceTime: referenceTime);
      expect(baselines.allowedHistogram.length, equals(24));
      expect(baselines.blockedHistogram.length, equals(24));

      // Sanity: totals represented by histograms should be >0 for this fixture.
      final allowedTotal =
          baselines.allowedHistogram.fold<int>(0, (sum, value) => sum + value);
      final blockedTotal =
          baselines.blockedHistogram.fold<int>(0, (sum, value) => sum + value);
      expect(allowedTotal, greaterThan(0));
      expect(blockedTotal, greaterThan(0));

      final uiStats = family_stats.UiStats(
        totalAllowed: baselines.totalAllowed,
        totalBlocked: baselines.totalBlocked,
        allowedHistogram: baselines.allowedHistogram,
        blockedHistogram: baselines.blockedHistogram,
        toplist: const [],
        avgDayAllowed: baselines.avgDayAllowed,
        avgDayBlocked: baselines.avgDayBlocked,
        avgDayTotal: baselines.avgDayTotal,
        latestTimestamp: baselines.latestTimestamp,
      );

      // Ratios should be finite and within bounds.
      expect(uiStats.dayAllowedRatio, inInclusiveRange(0, 100));
      expect(uiStats.dayBlockedRatio, inInclusiveRange(0, 100));
    });
  });
}
