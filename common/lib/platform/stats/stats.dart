import 'dart:async';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/device/device.dart';
import 'package:mobx/mobx.dart';

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
  Future<void> fetchToplists(Marker m) async {
    return await log(m).trace("fetchToplists", (m) async {
      toplistsLoading = true;
      try {
        final accountId = await _accountId.fetch(m);
        final deviceName = _device.deviceAlias;

        // Fetch blocked entries
        final toplistBlocked = await _api.getToplistV2(
          accountId: accountId,
          deviceName: deviceName,
          level: 1,
          action: "blocked",
          limit: 12,
          range: "24h",
          m: m,
        );

        // Fetch allowed entries (both "allowed" and "fallthrough" types)
        final toplistAllowed = await _api.getToplistV2(
          accountId: accountId,
          deviceName: deviceName,
          level: 1,
          action: "allowed",
          limit: 12,
          range: "24h",
          m: m,
        );

        final toplistFallthrough = await _api.getToplistV2(
          accountId: accountId,
          deviceName: deviceName,
          level: 1,
          action: "fallthrough",
          limit: 12,
          range: "24h",
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
      } finally {
        toplistsLoading = false;
      }
    });
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

  UiStats _convertStats(
      api.JsonStatsEndpoint stats, api.JsonStatsEndpoint oneWeek,
      {api.JsonToplistV2Response? toplistAllowed,
      api.JsonToplistV2Response? toplistBlocked,
      UiStats? previousStats}) {
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
        if (latestTimestamp < d.timestamp * 1000) {
          latestTimestamp = d.timestamp * 1000;
        }

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
    if (avgDayAllowed == 0) {
      avgDayAllowed = allowedHistogram.reduce((a, b) => a + b) * 24 * 2;
    }
    if (avgDayBlocked == 0) {
      avgDayBlocked = blockedHistogram.reduce((a, b) => a + b) * 24 * 2;
    }

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
