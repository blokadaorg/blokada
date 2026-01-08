import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/platform/stats/api.dart' as platform_stats;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitWeeklyTotalsFromStats', () {
    test('splits totals into previous and current weeks', () {
      final timestamps = _generateTimestamps();
      final allowed = <int, int>{};
      final blocked = <int, int>{};
      for (var i = 0; i < timestamps.length; i++) {
        allowed[timestamps[i]] = i + 1;
        blocked[timestamps[i]] = (i + 1) * 2;
      }

      final stats = _buildStats({
        'allowed': allowed,
        'blocked': blocked,
      });

      final result = splitWeeklyTotalsFromStats(stats);

      expect(result.previous.allowed, equals(28)); // 1+..+7
      expect(result.current.allowed, equals(77)); // 8+..+14
      expect(result.previous.blocked, equals(56)); // 2*(1+..+7)
      expect(result.current.blocked, equals(154)); // 2*(8+..+14)
      expect(
        result.anchor,
        DateTime.fromMillisecondsSinceEpoch(timestamps[7] * 1000, isUtc: true),
      );
    });

    test('treats missing daily buckets as zeroes', () {
      final timestamps = _generateTimestamps();
      final allowed = <int, int>{};
      final blocked = <int, int>{};
      for (var i = 0; i < timestamps.length; i++) {
        blocked[timestamps[i]] = 10;
        if (i != 9) {
          allowed[timestamps[i]] = 5;
        }
      }

      final stats = _buildStats({
        'allowed': allowed,
        'blocked': blocked,
      });

      final result = splitWeeklyTotalsFromStats(stats);

      expect(result.previous.allowed, equals(35));
      expect(result.current.allowed, equals(30)); // missing day counts as zero
      expect(result.current.blocked, equals(70));
      expect(result.previous.blocked, equals(70));
    });
  });
}

platform_stats.JsonStatsEndpoint _buildStats(Map<String, Map<int, int>> buckets) {
  final metrics = <platform_stats.JsonMetrics>[];
  buckets.forEach((action, values) {
    metrics.add(platform_stats.JsonMetrics(
      tags: platform_stats.JsonTags(action: action),
      dps: values.entries
          .map((entry) =>
              platform_stats.JsonDps(timestamp: entry.key, value: entry.value.toDouble()))
          .toList(),
    ));
  });

  return platform_stats.JsonStatsEndpoint(
    totalAllowed: '0',
    totalBlocked: '0',
    stats: platform_stats.JsonStats(metrics: metrics),
  );
}

List<int> _generateTimestamps() {
  const secondsPerDay = 24 * 60 * 60;
  final latest = DateTime.utc(2025, 1, 20).millisecondsSinceEpoch ~/ 1000;
  final timestamps = <int>[];
  for (var i = 13; i >= 0; i--) {
    timestamps.add(latest - i * secondsPerDay);
  }
  return timestamps;
}
