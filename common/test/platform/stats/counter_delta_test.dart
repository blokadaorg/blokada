import 'dart:convert';
import 'dart:io';

import 'package:common/platform/stats/api.dart' as api;
import 'package:common/platform/stats/delta_store.dart';
import 'package:common/platform/stats/stats.dart';
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
    });

    test('computes daily counters (24h vs previous 24h) from fixture', () {
      final raw = File('test/platform/stats/fixtures/stats_2w_iphone.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final endpoint = api.JsonStatsEndpoint.fromJson(decoded);

      final daily = buildPeriodCountersFromRollingStats(endpoint, days: 1);
      expect(daily.hasComparison, isTrue);

      final delta = computeCounterDelta(
        previous: daily.previous,
        current: daily.current,
        hasComparison: daily.hasComparison,
      );

      // Expected from fixture (percent change relative to previous window's same metric):
      // - Previous totals: allowed=7,826, blocked=2,769 => total=10,595
      // - Current totals:  allowed=5,926, blocked=2,726
      // - Allowed delta: (5,926 - 7,826) / 7,826 * 100 = -24.27... => -24% (rounded)
      // - Blocked delta: (2,726 - 2,769) / 2,769 * 100 = -1.55... => -2% (rounded)
      expect(delta.allowedPercent, equals(-24));
      expect(delta.blockedPercent, equals(-2));
    });

    test('returns 0 when baseline is zero', () {
      final delta = computeCounterDelta(
        previous: const StatsCounters(allowed: 0, blocked: 0, total: 0),
        current: const StatsCounters(allowed: 10, blocked: 5, total: 15),
        hasComparison: true,
      );

      expect(delta.allowedPercent, equals(0));
      expect(delta.blockedPercent, equals(0));
    });
  });
}
