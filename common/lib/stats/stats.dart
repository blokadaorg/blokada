import 'dart:async';
import 'package:common/stats/stats_sheet.dart';
import 'package:mobx/mobx.dart';

import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'stats.g.dart';

class UiStats {
  final int totalAllowed;
  final int totalBlocked;

  final List<int> allowedHistogram;
  final List<int> blockedHistogram;

  final List<UiToplistEntry> toplist;

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
    required this.totalAllowed,
    required this.totalBlocked,
    required this.allowedHistogram,
    required this.blockedHistogram,
    required this.toplist,
    required this.avgDayTotal,
    required this.avgDayAllowed,
    required this.avgDayBlocked,
    required this.latestTimestamp,
  }) {
    dayAllowed = allowedHistogram.reduce((a, b) => a + b);
    dayBlocked = blockedHistogram.reduce((a, b) => a + b);
    dayTotal = dayAllowed + dayBlocked;

    dayAllowedRatio = ((dayAllowed / avgDayAllowed) * 100);
    dayBlockedRatio = ((dayBlocked / avgDayBlocked) * 100);
    dayTotalRatio = dayAllowedRatio +
        dayBlockedRatio; // As per Johnny request, to make total ring always bigger than others
  }

  UiStats.empty({
    this.totalAllowed = 0,
    this.totalBlocked = 0,
    this.allowedHistogram = const [],
    this.blockedHistogram = const [],
    this.toplist = const [],
  });
}

class UiToplistEntry {
  final String? company;
  final String? tld;
  final bool blocked;
  final int value;

  UiToplistEntry(this.company, this.tld, this.blocked, this.value);
}

class StatsStore = StatsStoreBase with _$StatsStore;

abstract class StatsStoreBase with Store, Traceable, Dependable {
  late final _api = dep<StatsJson>();
  late final _ops = dep<StatsOps>();

  StatsStoreBase() {
    reactionOnStore((_) => stats, (stats) async {
      await _ops.doBlockedCounterChanged(formatCounter(stats.totalBlocked));
    });
  }

  String formatCounter(int counter) {
    if (counter >= 1000000) {
      return "${(counter / 1000000.0).toStringAsFixed(2)}M";
    } else if (counter >= 1000) {
      return "${(counter / 1000.0).toStringAsFixed(1)}K";
    } else {
      return "$counter";
    }
  }

  @override
  attach(Act act) {
    depend<StatsOps>(getOps(act));
    depend<StatsJson>(StatsJson());
    depend<StatsSheet>(StatsSheet());
    depend<StatsStore>(this as StatsStore);
  }

  @observable
  UiStats stats = UiStats.empty();

  @observable
  Map<String, UiStats> deviceStats = {};

  UiStats statsForSelectedDevice() {
    if (selectedDevice == null) {
      return stats;
    } else {
      return deviceStats[selectedDevice] ?? UiStats.empty();
    }
  }

  @observable
  int deviceStatsChangesCounter = 0;

  @observable
  String? selectedDevice;

  @observable
  bool selectedDeviceIsThisDevice = false;

  @observable
  bool hasStats = false;

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      final oneDay = await _api.getStats(trace, "24h", "1h");
      final oneWeek = await _api.getStats(trace, "1w", "24h");
      stats = _convertStats(oneDay, oneWeek);
      hasStats = true;
      deviceStatsChangesCounter++;
    });
  }

  @action
  Future<void> fetchForDevice(Trace parentTrace, String deviceName) async {
    return await traceWith(parentTrace, "fetchForDevice", (trace) async {
      final oneDay =
          await _api.getStatsForDevice(trace, "24h", "1h", deviceName);
      final oneWeek =
          await _api.getStatsForDevice(trace, "1w", "24h", deviceName);
      final toplist = await _api.getToplistForDevice(trace, deviceName);
      deviceStats[deviceName] =
          _convertStats(oneDay, oneWeek, toplist: toplist);
      deviceStatsChangesCounter++;
    });
  }

  @action
  Future<void> setSelectedDevice(
      Trace parentTrace, String deviceName, bool thisDevice) async {
    return await traceWith(parentTrace, "setSelectedDevice", (trace) async {
      if (!deviceStats.containsKey(deviceName)) {
        throw Exception("Unknown device");
      }
      selectedDevice = deviceName;
      selectedDeviceIsThisDevice = thisDevice;
    });
  }

  @action
  Future<void> drop(Trace parentTrace) async {
    return await traceWith(parentTrace, "drop", (trace) async {
      stats = UiStats.empty();
      deviceStats = {};
      deviceStatsChangesCounter = 0;
      hasStats = false;
    });
  }

  UiStats _convertStats(JsonStatsEndpoint stats, JsonStatsEndpoint oneWeek,
      {JsonToplistEndpoint? toplist}) {
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
        if (latestTimestamp < d.timestamp * 1000)
          latestTimestamp = d.timestamp * 1000;

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
          avgDayAllowed = (histogram
                      .sublist(0, histogram.length - 1)
                      .reduce((a, b) => a + b) /
                  (histogram.length - 1))
              .round();
          avgDayAllowed *= 2;
        } else {
          avgDayBlocked = (histogram
                      .sublist(0, histogram.length - 1)
                      .reduce((a, b) => a + b) /
                  (histogram.length - 1))
              .round();
          avgDayBlocked *= 2;
        }
      }
    }

    // Calculate last week's average based on this week (no data)
    if (avgDayAllowed == 0)
      avgDayAllowed = allowedHistogram.reduce((a, b) => a + b) * 24 * 2;
    if (avgDayBlocked == 0)
      avgDayBlocked = blockedHistogram.reduce((a, b) => a + b) * 24 * 2;

    final convertedToplist = toplist == null ? [] : _convertToplist(toplist);

    return UiStats(
        totalAllowed: int.parse(stats.totalAllowed),
        totalBlocked: int.parse(stats.totalBlocked),
        allowedHistogram: allowedHistogram,
        blockedHistogram: blockedHistogram,
        toplist: convertedToplist,
        avgDayAllowed: avgDayAllowed,
        avgDayBlocked: avgDayBlocked,
        avgDayTotal: avgDayAllowed + avgDayBlocked,
        latestTimestamp: latestTimestamp);
  }

  _convertToplist(JsonToplistEndpoint toplist) {
    final result = <UiToplistEntry>[];
    for (var metric in toplist.toplist.metrics) {
      final action = metric.tags.action;
      final isAllowed = action == "fallthrough" || action == "allowed";
      final firstDps = metric.dps.first;
      final c = (metric.tags.company == "unknown") ? null : metric.tags.company;
      result.add(UiToplistEntry(
          c, metric.tags.tld, !isAllowed, firstDps.value.round()));
    }
    //result.sort((a, b) => b.value.compareTo(a.value));
    return result;
  }
}
