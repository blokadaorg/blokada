part of 'stats.dart';

const _key = "statsRefresh";

class StatsActor with Logging, Actor {
  late final _api = Core.get<StatsApi>();
  late final _scheduler = Core.get<Scheduler>();
  late final _selectedDevice = Core.get<SelectedDeviceTag>();

  List<DeviceTag> monitorDeviceTags = [];

  Map<DeviceTag, UiStats> stats = {};

  Function(Marker) onStatsUpdated = (m) {};
  bool autoRefresh = false;

  @override
  onStart(Marker m) async {
    _selectedDevice.onChange.listen((event) async {
      await startAutoRefresh(Markers.device);
    });
  }

  fetch(Marker m, {bool forceFetchAll = false}) async {
    await log(m).trace("fetch", (m) async {
      var t = monitorDeviceTags;

      // Refresh only selected device when user is on device screen
      // When on home, fetch all devices, but more rarely
      final selected = await _selectedDevice.now();
      if (selected != null && !forceFetchAll) {
        t = [selected];
      }

      for (final tag in t) {
        final oneDay = await _api.fetch(m, tag, "24h", "1h");
        final oneWeek = await _api.fetch(m, tag, "1w", "24h");

        stats[tag] = _convertStats(
          oneDay,
          oneWeek,
          previousStats: stats[tag],
        );
      }
    });
  }

  fetchToplists(Marker m, {bool forceFetchAll = false}) async {
    await log(m).trace("fetchToplists", (m) async {
      var t = monitorDeviceTags;

      // Refresh only selected device when user is on device screen
      // When on home, fetch all devices, but more rarely
      final selected = await _selectedDevice.now();
      if (selected != null && !forceFetchAll) {
        t = [selected];
      }

      for (final tag in t) {
        platform_stats.JsonToplistV2Response? toplistAllowed;
        platform_stats.JsonToplistV2Response? toplistBlocked;

        try {
          // Fetch blocked entries
          toplistBlocked = await _api.fetchToplist(
            m: m,
            tag: tag,
            level: 1,
            action: "blocked",
            limit: 5,
            range: "24h",
          );

          // Fetch allowed entries
          toplistAllowed = await _api.fetchToplist(
            m: m,
            tag: tag,
            level: 1,
            action: "allowed",
            limit: 5,
            range: "24h",
          );
        } catch (e) {
          log(m).w("Failed to fetch toplists: $e");
        }

        // Update stats with toplists only
        if (stats.containsKey(tag)) {
          final currentStats = stats[tag]!;
          List<UiToplistEntry> convertedToplist = [];
          if (toplistAllowed != null) {
            convertedToplist.addAll(_convertToplistV2(toplistAllowed));
          }
          if (toplistBlocked != null) {
            convertedToplist.addAll(_convertToplistV2(toplistBlocked));
          }

          stats[tag] = UiStats(
            totalAllowed: currentStats.totalAllowed,
            totalBlocked: currentStats.totalBlocked,
            allowedHistogram: currentStats.allowedHistogram,
            blockedHistogram: currentStats.blockedHistogram,
            toplist: convertedToplist,
            avgDayAllowed: currentStats.avgDayAllowed,
            avgDayBlocked: currentStats.avgDayBlocked,
            avgDayTotal: currentStats.avgDayTotal,
            latestTimestamp: currentStats.latestTimestamp,
          );
        }
      }
    });
  }

  startAutoRefresh(Marker m) async {
    await log(m).trace("startAutoRefresh", (m) async {
      await _selectedDevice.fetch(m);
      await _scheduler.addOrUpdate(
          Job(
            _key,
            Markers.stats,
            every: _decideFrequency(),
            when: [Conditions.foreground],
            callback: _autoRefresh,
          ),
          immediate: true);
    });
  }

  stopAutoRefresh(Marker m) {
    _scheduler.stop(m, _key);
  }

  Future<bool> _autoRefresh(Marker m) async {
    try {
      await fetch(m);
    } catch (e, s) {
      log(m).e(msg: "Failed to fetch stats", err: e, stack: s);
    }
    await onStatsUpdated(m);
    return true;
  }

  Duration _decideFrequency() {
    if (_selectedDevice.present != null) {
      return const Duration(seconds: 10);
    }

    return const Duration(seconds: 120);
  }
}

UiStats _convertStats(
  JsonStatsEndpoint stats,
  JsonStatsEndpoint oneWeek, {
  UiStats? previousStats,
}) {
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

  // Keep previous toplist if available
  List<UiToplistEntry> convertedToplist = [];
  if (previousStats != null) {
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

List<UiToplistEntry> _convertToplistV2(platform_stats.JsonToplistV2Response response) {
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
