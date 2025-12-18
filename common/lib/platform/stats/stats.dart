import 'dart:async';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/stats/toplist_store.dart';
import 'package:mobx/mobx.dart';
import 'package:meta/meta.dart';

import 'api.dart' as api;

part 'stats.g.dart';

class StatsStore = StatsStoreBase with _$StatsStore;

abstract class StatsStoreBase with Store, Logging, Actor {
  late final _api = Core.get<api.StatsApi>();
  late final _device = Core.get<DeviceStore>();
  late final _accountId = Core.get<AccountId>();
  late final _toplists = Core.get<ToplistStore>();

  static const Duration _cacheTtl = Duration(seconds: 10);
  api.JsonStatsEndpoint? _lastDayEndpoint;
  api.JsonStatsEndpoint? _lastWeekEndpoint;
  api.JsonStatsEndpoint? _lastRolling2wEndpoint;
  DateTime? _lastDayFetch;
  DateTime? _lastWeekFetch;
  DateTime? _lastRolling2wFetch;

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
    await fetchDay(m);
  }

  Future<UiStats> fetchDay(Marker m, {bool force = false}) async {
    return await log(m).trace("fetchDay", (m) async {
      if (!force && _shouldUseCache(_lastDayFetch)) {
        return stats;
      }

      final deviceName = _deviceNameOrNull(m);
      if (deviceName == null) return stats;

      _lastDayEndpoint = await _api.getStats("48h", "1h", deviceName, m);
      _lastDayFetch = DateTime.now();
      _recomputeStats();
      return stats;
    });
  }

  Future<UiStats> fetchWeek(Marker m, {bool force = false}) async {
    return await log(m).trace("fetchWeek", (m) async {
      if (!force && _shouldUseCache(_lastWeekFetch)) {
        return stats;
      }

      final deviceName = _deviceNameOrNull(m);
      if (deviceName == null) return stats;

      _lastWeekEndpoint = await _api.getStats("1w", "24h", deviceName, m);
      _lastWeekFetch = DateTime.now();
      _recomputeStats();
      return stats;
    });
  }

  Future<StatsCounters> countersForRange(String range, Marker m, {bool force = false}) async {
    if (range == "7d") {
      await fetchWeek(m, force: force);
      return _buildCounters(_lastWeekEndpoint);
    }

    final deviceName = _deviceNameOrNull(m);
    if (deviceName == null) return StatsCounters.empty();

    final periods = await countersPeriods(range, deviceName, m, force: force);
    return periods.current;
  }

  Future<PeriodCounters> countersPeriods(String range, String deviceName, Marker m,
      {bool force = false}) async {
    final targetDevice = _deviceNameOrNull(m, override: deviceName);
    if (targetDevice == null) {
      return PeriodCounters(
        current: StatsCounters.empty(),
        previous: StatsCounters.empty(),
        hasComparison: false,
      );
    }

    if (range != "7d") {
      // For 24h deltas we want a true last-24h vs previous-24h comparison,
      // based on hourly buckets, independent of day boundaries.
      final rolling = await _api.getStats("48h", "1h", targetDevice, m);
      return buildHourlyPeriodCountersFromRollingStats(rolling, hours: 24);
    }

    // Weekly: use 2w/24h buckets and slice into current vs previous periods.
    final rolling = await _fetchRolling2w(m, targetDevice, force: force);
    if (range == "7d") {
      return buildPeriodCountersFromRollingStats(rolling, days: 7);
    }

    return PeriodCounters(
      current: StatsCounters.empty(),
      previous: StatsCounters.empty(),
      hasComparison: false,
    );
  }

  Future<DailySeries> allowedDailySeries(
      Marker m, {
        int days = 7,
        bool force = false,
      }) async {
    final deviceName = _deviceNameOrNull(m);
    if (deviceName == null) {
      return DailySeries.empty(Duration(days: 1));
    }
    final rolling = await _fetchRolling2w(m, deviceName, force: force);
    return buildAllowedDailySeriesFromRollingStats(rolling, days: days);
  }

  StatsCounters _buildCounters(api.JsonStatsEndpoint? endpoint) {
    if (endpoint == null) return StatsCounters.empty();
    int allowed = 0;
    int blocked = 0;
    for (final metric in endpoint.stats.metrics) {
      final isAllowed = metric.tags.action == "allowed" || metric.tags.action == "fallthrough";
      for (final d in metric.dps) {
        final rounded = d.value.round();
        if (isAllowed) {
          allowed += rounded;
        } else {
          blocked += rounded;
        }
      }
    }
    return StatsCounters(allowed: allowed, blocked: blocked, total: allowed + blocked);
  }

  void _recomputeStats() {
    final day = _lastDayEndpoint ?? _lastWeekEndpoint;
    final week = _lastWeekEndpoint ?? _lastDayEndpoint;

    if (day == null || week == null) {
      return;
    }

    runInAction(() {
      stats = _convertStats(
        day,
        week,
        previousStats: stats,
      );
      hasStats = true;
      deviceStatsChangesCounter++;
    });
  }

  bool _shouldUseCache(DateTime? lastFetch) {
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheTtl;
  }

  String? _deviceNameOrNull(Marker m, {String? override}) {
    final deviceName = (override ?? _device.deviceAlias).trim();
    if (deviceName.isEmpty) {
      log(m).w("deviceAlias not set yet, skipping stats fetch");
      return null;
    }
    return deviceName;
  }

  Future<api.JsonStatsEndpoint> _fetchRolling2w(
    Marker m,
    String deviceName, {
    bool force = false,
  }) async {
    if (!force && _shouldUseCache(_lastRolling2wFetch) && _lastRolling2wEndpoint != null) {
      return _lastRolling2wEndpoint!;
    }

    _lastRolling2wEndpoint = await _api.getStats("2w", "24h", deviceName, m);
    _lastRolling2wFetch = DateTime.now();
    return _lastRolling2wEndpoint!;
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
          final toplistBlocked = await _toplists.fetch(
            m: m,
            deviceName: deviceName,
            level: 1,
            action: "blocked",
            limit: 12,
            range: range,
          );

          // Fetch allowed entries (both "allowed" and "fallthrough" types)
          final toplistAllowed = await _toplists.fetch(
            m: m,
            deviceName: deviceName,
            level: 1,
            action: "allowed",
            limit: 12,
            range: range,
          );

          final toplistFallthrough = await _toplists.fetch(
            m: m,
            deviceName: deviceName,
            level: 1,
            action: "fallthrough",
            limit: 12,
            range: range,
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
      _lastDayEndpoint = null;
      _lastWeekEndpoint = null;
      _lastDayFetch = null;
      _lastWeekFetch = null;
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

class StatsCounters {
  final int allowed;
  final int blocked;
  final int total;

  const StatsCounters({
    required this.allowed,
    required this.blocked,
    required this.total,
  });

  static StatsCounters empty() => const StatsCounters(allowed: 0, blocked: 0, total: 0);
}

class PeriodCounters {
  final StatsCounters current;
  final StatsCounters previous;
  final bool hasComparison;

  const PeriodCounters({
    required this.current,
    required this.previous,
    this.hasComparison = true,
  });
}

class _BucketPoint {
  final int timestamp;
  final int value;

  _BucketPoint({required this.timestamp, required this.value});
}

class DailySeries {
  final List<int> values;
  final DateTime end;
  final Duration step;

  const DailySeries({
    required this.values,
    required this.end,
    required this.step,
  });

  static DailySeries empty(Duration step) =>
      DailySeries(values: const [], end: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), step: step);
}

@visibleForTesting
DailySeries buildAllowedDailySeriesFromRollingStats(
  api.JsonStatsEndpoint endpoint, {
  required int days,
}) {
  final allowedByDay = <int, int>{};
  for (final metric in endpoint.stats.metrics) {
    final isAllowed = metric.tags.action == "allowed" || metric.tags.action == "fallthrough";
    if (!isAllowed) continue;
    for (final d in metric.dps) {
      final ts = d.timestamp;
      final value = d.value.round();
      allowedByDay[ts] = (allowedByDay[ts] ?? 0) + value;
    }
  }

  if (allowedByDay.isEmpty) {
    return DailySeries.empty(const Duration(days: 1));
  }

  final sortedTimestamps = allowedByDay.keys.toList()..sort();
  final endTimestamp = sortedTimestamps.last;
  final secondsPerDay = const Duration(days: 1).inSeconds;
  final startTimestamp = endTimestamp - (days - 1) * secondsPerDay;
  final values = <int>[];
  for (var i = 0; i < days; i++) {
    final ts = startTimestamp + (i * secondsPerDay);
    values.add(allowedByDay[ts] ?? 0);
  }
  final end =
      DateTime.fromMillisecondsSinceEpoch(endTimestamp * 1000, isUtc: true);

  return DailySeries(values: values, end: end, step: const Duration(days: 1));
}

@visibleForTesting
PeriodCounters buildPeriodCountersFromRollingStats(api.JsonStatsEndpoint endpoint,
    {required int days}) {
  final allowedPoints = <_BucketPoint>[];
  final blockedPoints = <_BucketPoint>[];

  for (final metric in endpoint.stats.metrics) {
    final isAllowed = metric.tags.action == "allowed" || metric.tags.action == "fallthrough";
    for (final d in metric.dps) {
      final point = _BucketPoint(timestamp: d.timestamp, value: d.value.round());
      if (isAllowed) {
        allowedPoints.add(point);
      } else {
        blockedPoints.add(point);
      }
    }
  }

  if (allowedPoints.isEmpty && blockedPoints.isEmpty) {
    return PeriodCounters(
      current: StatsCounters.empty(),
      previous: StatsCounters.empty(),
      hasComparison: false,
    );
  }

  allowedPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  blockedPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final allPoints = [...allowedPoints, ...blockedPoints];
  final allTimestamps = allPoints.map((p) => p.timestamp).toList();
  final latestTs = allTimestamps.reduce((a, b) => a > b ? a : b);

  final usesMillis = latestTs > 10000000000; // crude detection for ms vs s
  final dayUnit = usesMillis ? Duration(days: 1).inMilliseconds : Duration(days: 1).inSeconds;

  final uniqueDays = <int>{};
  for (final ts in allTimestamps) {
    uniqueDays.add(ts ~/ dayUnit);
  }

  int sumWindow(List<_BucketPoint> points, int startInclusive, int endExclusive) {
    var sum = 0;
    for (final p in points) {
      if (p.timestamp >= startInclusive && p.timestamp < endExclusive) {
        sum += p.value;
      }
    }
    return sum;
  }

  final currentEnd = latestTs + dayUnit;
  final currentStart = currentEnd - days * dayUnit;
  final previousEnd = currentStart;
  final previousStart = previousEnd - days * dayUnit;

  final allowedCurrent = sumWindow(allowedPoints, currentStart, currentEnd);
  final blockedCurrent = sumWindow(blockedPoints, currentStart, currentEnd);
  final allowedPrevious = sumWindow(allowedPoints, previousStart, previousEnd);
  final blockedPrevious = sumWindow(blockedPoints, previousStart, previousEnd);

  final current = StatsCounters(
    allowed: allowedCurrent,
    blocked: blockedCurrent,
    total: allowedCurrent + blockedCurrent,
  );
  final previous = StatsCounters(
    allowed: allowedPrevious,
    blocked: blockedPrevious,
    total: allowedPrevious + blockedPrevious,
  );

  final hasComparison = uniqueDays.length >= days * 2;

  return PeriodCounters(
    current: current,
    previous: previous,
    hasComparison: hasComparison,
  );
}

@visibleForTesting
PeriodCounters buildHourlyPeriodCountersFromRollingStats(
  api.JsonStatsEndpoint endpoint, {
  required int hours,
  DateTime? referenceTime,
}) {
  final allowedPoints = <_BucketPoint>[];
  final blockedPoints = <_BucketPoint>[];

  for (final metric in endpoint.stats.metrics) {
    final isAllowed = metric.tags.action == "allowed" || metric.tags.action == "fallthrough";
    for (final d in metric.dps) {
      final point = _BucketPoint(timestamp: d.timestamp, value: d.value.round());
      if (isAllowed) {
        allowedPoints.add(point);
      } else {
        blockedPoints.add(point);
      }
    }
  }

  if (allowedPoints.isEmpty && blockedPoints.isEmpty) {
    return PeriodCounters(
      current: StatsCounters.empty(),
      previous: StatsCounters.empty(),
      hasComparison: false,
    );
  }

  final now = (referenceTime ?? DateTime.now().toUtc());
  final anchor = DateTime.utc(now.year, now.month, now.day, now.hour);
  final anchorSeconds = anchor.millisecondsSinceEpoch ~/ 1000;

  final hourUnit = Duration(hours: 1).inSeconds;
  final currentEnd = anchorSeconds;
  final currentStart = currentEnd - hours * hourUnit;
  final previousEnd = currentStart;
  final previousStart = previousEnd - hours * hourUnit;

  int sumWindow(List<_BucketPoint> points, int startInclusive, int endExclusive) {
    var sum = 0;
    for (final p in points) {
      if (p.timestamp >= startInclusive && p.timestamp < endExclusive) {
        sum += p.value;
      }
    }
    return sum;
  }

  final allowedCurrent = sumWindow(allowedPoints, currentStart, currentEnd);
  final blockedCurrent = sumWindow(blockedPoints, currentStart, currentEnd);
  final allowedPrevious = sumWindow(allowedPoints, previousStart, previousEnd);
  final blockedPrevious = sumWindow(blockedPoints, previousStart, previousEnd);

  final current = StatsCounters(
    allowed: allowedCurrent,
    blocked: blockedCurrent,
    total: allowedCurrent + blockedCurrent,
  );
  final previous = StatsCounters(
    allowed: allowedPrevious,
    blocked: blockedPrevious,
    total: allowedPrevious + blockedPrevious,
  );

  final uniqueHours = <int>{};
  for (final p in [...allowedPoints, ...blockedPoints]) {
    uniqueHours.add(p.timestamp ~/ hourUnit);
  }

  final hasComparison = uniqueHours.length >= hours * 2;

  return PeriodCounters(
    current: current,
    previous: previous,
    hasComparison: hasComparison,
  );
}
