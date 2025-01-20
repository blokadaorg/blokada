import 'dart:async';

import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/stats/stats_sheet.dart';
import 'package:mobx/mobx.dart';

import 'json.dart' as json;

part 'stats.g.dart';

class StatsStore = StatsStoreBase with _$StatsStore;

abstract class StatsStoreBase with Store, Logging, Actor {
  late final _api = Core.get<json.StatsJson>();

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

  @override
  onRegister() {
    Core.register<json.StatsJson>(json.StatsJson());
    Core.register<StatsSheet>(StatsSheet());
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

  @action
  Future<void> fetch(Marker m) async {
    return await log(m).trace("fetch", (m) async {
      final oneDay = await _api.getStats("24h", "1h", m);
      final oneWeek = await _api.getStats("1w", "24h", m);
      stats = _convertStats(oneDay, oneWeek);
      hasStats = true;
      deviceStatsChangesCounter++;
    });
  }

  @action
  Future<void> fetchForDevice(String deviceName, Marker m,
      {bool toplists = false}) async {
    return await log(m).trace("fetchForDevice", (m) async {
      final oneDay = await _api.getStatsForDevice("24h", "1h", deviceName, m);
      final oneWeek = await _api.getStatsForDevice("1w", "24h", deviceName, m);

      final toplistAllowed = !toplists
          ? null
          : await _api.getToplistForDevice(false, deviceName, m);
      final toplistBlocked = !toplists
          ? null
          : await _api.getToplistForDevice(true, deviceName, m);

      deviceStats[deviceName] = _convertStats(
        oneDay,
        oneWeek,
        toplistAllowed: toplistAllowed,
        toplistBlocked: toplistBlocked,
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
      json.JsonStatsEndpoint stats, json.JsonStatsEndpoint oneWeek,
      {json.JsonToplistEndpoint? toplistAllowed,
      json.JsonToplistEndpoint? toplistBlocked,
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

    List<UiToplistEntry> convertedToplist =
        toplistAllowed == null ? [] : _convertToplist(toplistAllowed);
    convertedToplist = convertedToplist +
        (toplistBlocked == null ? [] : _convertToplist(toplistBlocked));

    if (convertedToplist.isEmpty) {
      convertedToplist = previousStats?.toplist ?? [];
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

  _convertToplist(json.JsonToplistEndpoint toplist) {
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
