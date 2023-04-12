import 'dart:async';
import 'package:mobx/mobx.dart';

import '../util/di.dart';
import '../util/trace.dart';
import 'json.dart';

part 'stats.g.dart';

class UiStats {

  final int totalAllowed;
  final int totalBlocked;

  final List<int> allowedHistogram;
  final List<int> blockedHistogram;

  int latestTimestamp = DateTime.now().millisecondsSinceEpoch;

  // Sum for the current day
  int dayAllowed = 0;
  int dayBlocked = 0;
  int dayTotal = 0;

  // Average values per day (taken from at least a week of data)
  int avgDayAllowed = 0;
  int avgDayBlocked = 0;
  int avgDayTotal = 0;

  // Value 0-100 meaning what % of the average daily is the value for the current day
  double dayAllowedRatio = 0;
  double dayBlockedRatio = 0;
  double dayTotalRatio = 0;

  UiStats({
    required this.totalAllowed, required this.totalBlocked,
    required this.allowedHistogram, required this.blockedHistogram,
    required this.avgDayTotal, required this.avgDayAllowed, required this.avgDayBlocked,
    required this.latestTimestamp,
  }) {
    dayAllowed = allowedHistogram.reduce((a, b) => a + b);
    dayBlocked = blockedHistogram.reduce((a, b) => a + b);
    dayTotal = dayAllowed + dayBlocked;

    dayAllowedRatio = ((dayAllowed / avgDayAllowed) * 100);
    dayBlockedRatio = ((dayBlocked / avgDayBlocked) * 100);
    dayTotalRatio = dayAllowedRatio + dayBlockedRatio; // As per Johnny request, to make total ring always bigger than others
  }

  UiStats.empty({
    this.totalAllowed = 0, this.totalBlocked = 0,
    this.allowedHistogram = const [], this.blockedHistogram = const [],
  });

}

class UiStatsPair {
  final DateTime timestamp;
  final int value;

  UiStatsPair({required this.timestamp, required this.value});
}

class StatsStore = StatsStoreBase with _$StatsStore;
abstract class StatsStoreBase with Store, Traceable {
  late final _api = di<StatsJson>();

  @observable
  UiStats stats = UiStats.empty();

  @observable
  bool hasStats = false;

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      final oneDay = await _api.getStats(trace, "24h", "1h");
      final oneWeek = await _api.getStats(trace, "1w", "24h");
      stats = _convertStats(oneDay, oneWeek);
      hasStats = true;
    });
  }

  UiStats _convertStats(JsonStatsEndpoint stats, JsonStatsEndpoint oneWeek) {
    int now = DateTime.now().millisecondsSinceEpoch;
    now = now ~/ 1000; // Drop microseconds
    now = now - now % 3600; // Round down to the nearest hour

    //final rng = Random();
    //List<int> allowedHistogram = List.filled(24, rng.nextInt(500));
    List<int> allowedHistogram = List.filled(24, 0);
    List<int> blockedHistogram = List.filled(24, 0);
    int latestTimestamp = 0;

    for (var metric in stats.stats.metrics) {
      final action = metric.tags.action;
      final isAllowed = action == "fallthrough" || action == "allowed";
      metric.dps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (var d in metric.dps) {
        final diffHours = ((now - d.timestamp) ~/ 3600);
        final hourIndex = 24 - diffHours - 1;

        if (hourIndex < 0) continue;
        if (latestTimestamp < d.timestamp * 1000) latestTimestamp = d.timestamp * 1000;

        if (isAllowed) {
          allowedHistogram[hourIndex] = d.value.round();
        } else {
          blockedHistogram[hourIndex] = d.value.round();
        }
      }
    }

    // Also parse the weekly sample to get the average
    var avgDayAllowed = 0;
    var avgDayBlocked = 0;
    for (var metric in oneWeek.stats.metrics) {
      final action = metric.tags.action;
      final isAllowed = action == "fallthrough" || action == "allowed";
      metric.dps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final histogram = metric.dps.map((d) => d.value.round()).toList();

      // Get previous week if available
      if (histogram.length >= 2) {
        if (isAllowed) {
          avgDayAllowed = (histogram.sublist(0, histogram.length - 1).reduce((a, b) => a + b) / (histogram.length - 1)).round();
          avgDayAllowed *= 2;
        } else {
          avgDayBlocked = (histogram.sublist(0, histogram.length - 1).reduce((a, b) => a + b) / (histogram.length - 1)).round();
          avgDayBlocked *= 2;
        }
      }
    }

    // Calculate last week's average based on this week (no data)
    if (avgDayAllowed == 0) avgDayAllowed = allowedHistogram.reduce((a, b) => a + b) * 24 * 2;
    if (avgDayBlocked == 0) avgDayBlocked = blockedHistogram.reduce((a, b) => a + b) * 24 * 2;

    return UiStats(
      totalAllowed: int.parse(stats.totalAllowed),
      totalBlocked: int.parse(stats.totalBlocked),
      allowedHistogram: allowedHistogram,
      blockedHistogram: blockedHistogram,
      avgDayAllowed: avgDayAllowed, avgDayBlocked: avgDayBlocked, avgDayTotal: avgDayAllowed + avgDayBlocked,
      latestTimestamp: latestTimestamp
    );
  }
}

Future<void> init() async {
  di.registerSingleton<StatsJson>(StatsJson());
  di.registerSingleton<StatsStore>(StatsStore());
}
