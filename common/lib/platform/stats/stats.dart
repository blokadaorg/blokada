import 'dart:async';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/device/device.dart';
import 'package:mobx/mobx.dart';
import 'package:meta/meta.dart';

import 'api.dart' as api;

part 'stats.g.dart';

class StatsStore = StatsStoreBase with _$StatsStore;

abstract class StatsStoreBase with Store, Logging, Actor {
  late final _api = Core.get<api.StatsApi>();
  late final _device = Core.get<DeviceStore>();
  late final _accountId = Core.get<AccountId>();

  StatsStoreBase() {}

  static String formatCounter(int counter) {
    if (counter >= 1000000) {
      return "${(counter / 1000000.0).toStringAsFixed(2)}M";
    } else if (counter >= 1000) {
      return "${(counter / 1000.0).toStringAsFixed(1)}K";
    } else {
      return "$counter";
    }
  }

  onRegister() {
    Core.register<api.StatsApi>(api.StatsApi());
    Core.register<StatsStore>(this as StatsStore);
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

  // TODO: Ugly hack
  UiStats totalStats() {
    return deviceStats.entries.firstOrNull?.value ?? stats;
  }

  @observable
  int deviceStatsChangesCounter = 0;

  @observable
  String? selectedDevice;

  @observable
  bool selectedDeviceIsThisDevice = false;

  @observable
  bool hasStats = false;

  @observable
  bool toplistsLoading = false;

  @action
  Future<void> fetch(Marker m) async {
    return await log(m).trace("fetch", (m) async {
      final oneDay = await _api.getStats("24h", "1h", m);
      final oneWeek = await _api.getStats("1w", "24h", m);

      stats = _convertStats(
        oneDay,
        oneWeek,
        previousStats: stats,
      );
      hasStats = true;
      deviceStatsChangesCounter++;
    });
  }

  @action
  Future<void> fetchToplists(Marker m, {String range = "24h"}) async {
    toplistsLoading = true;
    try {
      return await log(m).trace("fetchToplists", (m) async {
        try {
          final accountId = await _accountId.fetch(m);
          final deviceName = _device.deviceAlias;

          // Guard: Don't fetch if deviceAlias is not set yet
          if (deviceName.isEmpty) {
            log(m).w("deviceAlias not set yet, skipping toplist fetch");
            toplistsLoading = false;
            return;
          }

          // Fetch blocked entries
          final toplistBlocked = await _api.getToplistV2(
            accountId: accountId,
            deviceName: deviceName,
            level: 1,
            action: "blocked",
            limit: 12,
            range: range,
            m: m,
          );

          // Fetch allowed entries (both "allowed" and "fallthrough" types)
          final toplistAllowed = await _api.getToplistV2(
            accountId: accountId,
            deviceName: deviceName,
            level: 1,
            action: "allowed",
            limit: 12,
            range: range,
            m: m,
          );

          final toplistFallthrough = await _api.getToplistV2(
            accountId: accountId,
            deviceName: deviceName,
            level: 1,
            action: "fallthrough",
            limit: 12,
            range: range,
            m: m,
          );

          // Convert and merge allowed + fallthrough entries
          List<UiToplistEntry> convertedToplist = [];
          if (toplistBlocked != null) {
            convertedToplist.addAll(_convertToplistV2(toplistBlocked));
          }

          // Merge allowed and fallthrough entries
          if (toplistAllowed != null || toplistFallthrough != null) {
            convertedToplist.addAll(_mergeAllowedToplists(toplistAllowed, toplistFallthrough));
          }

          // Update stats with new toplist
          stats = UiStats(
            totalAllowed: stats.totalAllowed,
            totalBlocked: stats.totalBlocked,
            allowedHistogram: stats.allowedHistogram,
            blockedHistogram: stats.blockedHistogram,
            toplist: convertedToplist,
            avgDayAllowed: stats.avgDayAllowed,
            avgDayBlocked: stats.avgDayBlocked,
            avgDayTotal: stats.avgDayTotal,
            latestTimestamp: stats.latestTimestamp,
          );
          deviceStatsChangesCounter++;
        } catch (e) {
          log(m).w("Failed to fetch toplists: $e");
          // Set empty toplist on error - only update toplist field
          stats = UiStats(
            totalAllowed: stats.totalAllowed,
            totalBlocked: stats.totalBlocked,
            allowedHistogram: stats.allowedHistogram.isEmpty ? [0] : stats.allowedHistogram,
            blockedHistogram: stats.blockedHistogram.isEmpty ? [0] : stats.blockedHistogram,
            toplist: [],
            avgDayAllowed: stats.avgDayAllowed == 0 ? 1 : stats.avgDayAllowed,
            avgDayBlocked: stats.avgDayBlocked == 0 ? 1 : stats.avgDayBlocked,
            avgDayTotal: stats.avgDayTotal,
            latestTimestamp: stats.latestTimestamp,
          );
          deviceStatsChangesCounter++;
        }
      });
    } finally {
      toplistsLoading = false;
    }
  }

  @action
  Future<void> fetchForDevice(String deviceName, Marker m) async {
    return await log(m).trace("fetchForDevice", (m) async {
      final oneDay = await _api.getStatsForDevice("24h", "1h", deviceName, m);
      final oneWeek = await _api.getStatsForDevice("1w", "24h", deviceName, m);

      deviceStats[deviceName] = _convertStats(
        oneDay,
        oneWeek,
        previousStats: deviceStats[deviceName],
      );
      deviceStatsChangesCounter++;
    });
  }

  @action
  Future<void> setSelectedDevice(
      Marker m, String deviceName, bool thisDevice) async {
    return await log(m).trace("setSelectedDevice", (m) async {
      if (!deviceStats.containsKey(deviceName)) {
        throw Exception("Unknown device");
      }
      selectedDevice = deviceName;
      selectedDeviceIsThisDevice = thisDevice;
    });
  }

  @action
  Future<void> drop(Marker m) async {
    return await log(m).trace("drop", (m) async {
      stats = UiStats.empty();
      deviceStats = {};
      deviceStatsChangesCounter = 0;
      hasStats = false;
    });
  }

  @visibleForTesting
  UiStats convertStatsForTesting(
    api.JsonStatsEndpoint stats,
    api.JsonStatsEndpoint oneWeek, {
    api.JsonToplistV2Response? toplistAllowed,
    api.JsonToplistV2Response? toplistBlocked,
    UiStats? previousStats,
  }) {
    return _convertStats(
      stats,
      oneWeek,
      toplistAllowed: toplistAllowed,
      toplistBlocked: toplistBlocked,
      previousStats: previousStats,
    );
  }

  UiStats _convertStats(
      api.JsonStatsEndpoint stats, api.JsonStatsEndpoint oneWeek,
      {api.JsonToplistV2Response? toplistAllowed,
      api.JsonToplistV2Response? toplistBlocked,
      UiStats? previousStats}) {
    final result = computeStatsBaselines(stats, oneWeek);

    List<UiToplistEntry> convertedToplist = [];
    if (toplistAllowed != null || toplistBlocked != null) {
      if (toplistAllowed != null) {
        convertedToplist.addAll(_convertToplistV2(toplistAllowed));
      }
      if (toplistBlocked != null) {
        convertedToplist.addAll(_convertToplistV2(toplistBlocked));
      }
    } else if (previousStats != null) {
      convertedToplist = previousStats.toplist;
    }

    return UiStats(
      totalAllowed: result.totalAllowed,
      totalBlocked: result.totalBlocked,
      allowedHistogram: result.allowedHistogram,
      blockedHistogram: result.blockedHistogram,
      toplist: convertedToplist,
      avgDayAllowed: result.avgDayAllowed,
      avgDayBlocked: result.avgDayBlocked,
      avgDayTotal: result.avgDayTotal,
      latestTimestamp: result.latestTimestamp,
    );
  }

  List<UiToplistEntry> _convertToplistV2(api.JsonToplistV2Response response) {
    final result = <UiToplistEntry>[];
    for (var bucket in response.toplist) {
      final isAllowed = bucket.action == "fallthrough" || bucket.action == "allowed";
      for (var entry in bucket.entries) {
        result.add(UiToplistEntry(
          entry.name,      // Use name as company
          entry.name,      // Use name as tld
          !isAllowed,      // blocked flag
          entry.count,     // request count
        ));
      }
    }
    return result;
  }

  List<UiToplistEntry> _mergeAllowedToplists(
      api.JsonToplistV2Response? allowed, api.JsonToplistV2Response? fallthrough) {
    // Collect all entries from both responses
    final entries = <String, int>{};

    // Process allowed entries
    if (allowed != null) {
      for (var bucket in allowed.toplist) {
        for (var entry in bucket.entries) {
          entries[entry.name] = (entries[entry.name] ?? 0) + entry.count;
        }
      }
    }

    // Process fallthrough entries and merge with allowed
    if (fallthrough != null) {
      for (var bucket in fallthrough.toplist) {
        for (var entry in bucket.entries) {
          entries[entry.name] = (entries[entry.name] ?? 0) + entry.count;
        }
      }
    }

    // Convert to UiToplistEntry and sort by count descending
    final result = entries.entries
        .map((e) => UiToplistEntry(
              e.key,    // Use name as company
              e.key,    // Use name as tld
              false,    // Not blocked (these are allowed)
              e.value,  // Merged count
            ))
        .toList();

    // Sort by count descending
    result.sort((a, b) => b.value.compareTo(a.value));

    return result;
  }
}

class StatsComputationResult {
  StatsComputationResult({
    required this.totalAllowed,
    required this.totalBlocked,
    required this.allowedHistogram,
    required this.blockedHistogram,
    required this.avgDayAllowed,
    required this.avgDayBlocked,
    required this.avgDayTotal,
    required this.latestTimestamp,
  });

  final int totalAllowed;
  final int totalBlocked;
  final List<int> allowedHistogram;
  final List<int> blockedHistogram;
  final int avgDayAllowed;
  final int avgDayBlocked;
  final int avgDayTotal;
  final int latestTimestamp;
}

StatsComputationResult computeStatsBaselines(
    api.JsonStatsEndpoint stats, api.JsonStatsEndpoint oneWeek,
    {DateTime? referenceTime}) {
  int now =
      (referenceTime ?? DateTime.now()).millisecondsSinceEpoch;
  now = now ~/ 1000; // Drop microseconds
  now = now - now % 3600; // Round down to the nearest hour

  final allowedHistogram = List<int>.filled(24, 0);
  final blockedHistogram = List<int>.filled(24, 0);
  int latestTimestamp = 0;

  for (var metric in stats.stats.metrics) {
    final action = metric.tags.action;
    final isAllowed = action == "fallthrough" || action == "allowed";
    metric.dps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (var d in metric.dps) {
      final diffHours = ((now - d.timestamp) ~/ 3600);
      final hourIndex = 24 - diffHours - 1;

      if (hourIndex < 0) continue;
      if (latestTimestamp < d.timestamp * 1000) {
        latestTimestamp = d.timestamp * 1000;
      }

      final rounded = d.value.round();
      if (isAllowed) {
        allowedHistogram[hourIndex] += rounded;
      } else {
        blockedHistogram[hourIndex] += rounded;
      }
    }
  }

  final allowedDailyTotals = <int, int>{};
  final blockedDailyTotals = <int, int>{};

  void addDailyTotals(Map<int, int> target, List<api.JsonDps> dps) {
    for (var point in dps) {
      final timestamp = point.timestamp;
      final value = point.value.round();
      target[timestamp] = (target[timestamp] ?? 0) + value;
    }
  }

  for (var metric in oneWeek.stats.metrics) {
    final action = metric.tags.action;
    final isAllowed = action == "fallthrough" || action == "allowed";
    metric.dps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (metric.dps.isEmpty) continue;

    if (isAllowed) {
      addDailyTotals(allowedDailyTotals, metric.dps);
    } else {
      addDailyTotals(blockedDailyTotals, metric.dps);
    }
  }

  int fallbackFromHistogram(List<int> histogram) {
    final fallbackSum = histogram.fold<int>(0, (a, b) => a + b);
    return fallbackSum * 24 * 2;
  }

  int calculateAverage(Map<int, int> totals, List<int> fallbackHistogram) {
    if (totals.isEmpty) {
      return fallbackFromHistogram(fallbackHistogram);
    }

    final sortedTotals = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedTotals.length <= 1) {
      return fallbackFromHistogram(fallbackHistogram);
    }

    final previousEntries = sortedTotals.sublist(0, sortedTotals.length - 1);
    final previousValues = previousEntries.map((e) => e.value);
    final sum = previousValues.fold<int>(0, (a, b) => a + b);
    if (sum == 0) {
      return fallbackFromHistogram(fallbackHistogram);
    }
    final avg = (sum / previousEntries.length).round();
    return avg * 2;
  }

  final avgDayAllowed = calculateAverage(allowedDailyTotals, allowedHistogram);
  final avgDayBlocked = calculateAverage(blockedDailyTotals, blockedHistogram);

  return StatsComputationResult(
    totalAllowed: int.parse(stats.totalAllowed),
    totalBlocked: int.parse(stats.totalBlocked),
    allowedHistogram: allowedHistogram,
    blockedHistogram: blockedHistogram,
    avgDayAllowed: avgDayAllowed,
    avgDayBlocked: avgDayBlocked,
    avgDayTotal: avgDayAllowed + avgDayBlocked,
    latestTimestamp: latestTimestamp,
  );
}
