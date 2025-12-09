import 'dart:collection';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/stats/api.dart' as api;
import 'package:common/platform/stats/stats.dart';
import 'package:common/platform/stats/toplist_store.dart';

enum ToplistDeltaType { up, down, newEntry, same }

class ToplistDelta {
  final String name;
  final bool blocked;
  final int newRank;
  final int? previousRank;
  final ToplistDeltaType type;

  ToplistDelta({
    required this.name,
    required this.blocked,
    required this.newRank,
    required this.previousRank,
    required this.type,
  });
}

class CounterDelta {
  final int allowedPercent;
  final int blockedPercent;

  const CounterDelta({required this.allowedPercent, required this.blockedPercent});

  static CounterDelta empty() => const CounterDelta(allowedPercent: 0, blockedPercent: 0);
}

class StatsDeltaStore with Logging, Actor {
  static const Duration defaultTtl = Duration(seconds: 10);

  late final _toplists = Core.get<ToplistStore>();
  late final _stats = Core.get<StatsStore>();

  final _snapshots = HashMap<_DeltaKey, _SnapshotPair>();

  @override
  onRegister() {
    Core.register<StatsDeltaStore>(this);
  }

  Future<void> refresh(Marker m,
      {required String deviceName, required String range, bool force = false}) async {
    final key = _DeltaKey(deviceName: deviceName, range: range);
    final existing = _snapshots[key];
    if (!force && existing != null && DateTime.now().difference(existing.updatedAt) < defaultTtl) {
      return;
    }

    final now = DateTime.now().toUtc();
    final duration = _rangeToDuration(range);
    final prevEnd = now.subtract(duration);

    // Current window
    final blockedCurrent = await _toplists.fetch(
      m: m,
      deviceName: deviceName,
      level: 1,
      action: "blocked",
      limit: 12,
      range: range,
      end: now.toIso8601String(),
      force: true,
    );
    final allowedCurrent = await _toplists.fetch(
      m: m,
      deviceName: deviceName,
      level: 1,
      action: "allowed",
      limit: 12,
      range: range,
      end: now.toIso8601String(),
      force: true,
    );
    final fallthroughCurrent = await _toplists.fetch(
      m: m,
      deviceName: deviceName,
      level: 1,
      action: "fallthrough",
      limit: 12,
      range: range,
      end: now.toIso8601String(),
      force: true,
    );

    // Previous window (shifted back by one duration)
    final blockedPrev = await _toplists.fetch(
      m: m,
      deviceName: deviceName,
      level: 1,
      action: "blocked",
      limit: 12,
      range: range,
      end: prevEnd.toIso8601String(),
      force: true,
    );
    final allowedPrev = await _toplists.fetch(
      m: m,
      deviceName: deviceName,
      level: 1,
      action: "allowed",
      limit: 12,
      range: range,
      end: prevEnd.toIso8601String(),
      force: true,
    );
    final fallthroughPrev = await _toplists.fetch(
      m: m,
      deviceName: deviceName,
      level: 1,
      action: "fallthrough",
      limit: 12,
      range: range,
      end: prevEnd.toIso8601String(),
      force: true,
    );

    final countersPeriod = await _stats.countersPeriods(range, m, force: force);

    final allowedMergedCurrent = _mergeAllowed(allowedCurrent, fallthroughCurrent);
    final allowedMergedPrev = _mergeAllowed(allowedPrev, fallthroughPrev);
    final blockedEntriesCurrent = _convertToplist(blockedCurrent);
    final blockedEntriesPrev = _convertToplist(blockedPrev);

    final pair = _SnapshotPair(
      previous: _Snapshot(
        blocked: blockedEntriesPrev,
        allowed: allowedMergedPrev,
        counters: countersPeriod.previous,
      ),
      current: _Snapshot(
        blocked: blockedEntriesCurrent,
        allowed: allowedMergedCurrent,
        counters: countersPeriod.current,
      ),
      updatedAt: DateTime.now(),
    );
    _snapshots[key] = pair;
  }

  Duration _rangeToDuration(String range) {
    switch (range) {
      case "7d":
        return const Duration(days: 7);
      case "24h":
      default:
        return const Duration(hours: 24);
    }
  }

  List<ToplistDelta> deltasFor(String deviceName, String range, {required bool blocked}) {
    final pair = _snapshots[_DeltaKey(deviceName: deviceName, range: range)];
    if (pair == null || pair.current == null) return [];

    // If no previous snapshot, treat all current entries as new
    if (pair.previous == null) {
      final currentList = blocked ? pair.current!.blocked : pair.current!.allowed;
      final deltas = <ToplistDelta>[];
      for (var i = 0; i < currentList.length; i++) {
        final entry = currentList[i];
        final name = (entry.company ?? entry.tld ?? "").toLowerCase();
        deltas.add(ToplistDelta(
          name: name,
          blocked: blocked,
          newRank: i + 1,
          previousRank: null,
          type: ToplistDeltaType.newEntry,
        ));
      }
      return deltas;
    }

    final currentList = blocked ? pair.current!.blocked : pair.current!.allowed;
    final previousList = blocked ? pair.previous!.blocked : pair.previous!.allowed;

    final previousRanks = <String, int>{};
    for (var i = 0; i < previousList.length; i++) {
      final name = (previousList[i].company ?? previousList[i].tld ?? "").toLowerCase();
      previousRanks[name] = i + 1;
    }

    final deltas = <ToplistDelta>[];
    for (var i = 0; i < currentList.length; i++) {
      final entry = currentList[i];
      final name = (entry.company ?? entry.tld ?? "").toLowerCase();
      final newRank = i + 1;
      final prevRank = previousRanks[name];
      final type = prevRank == null
          ? ToplistDeltaType.newEntry
          : (prevRank > newRank
              ? ToplistDeltaType.up
              : (prevRank < newRank ? ToplistDeltaType.down : ToplistDeltaType.same));
      deltas.add(ToplistDelta(
        name: entry.company ?? entry.tld ?? "",
        blocked: blocked,
        newRank: newRank,
        previousRank: prevRank,
        type: type,
      ));
    }

    return deltas;
  }

  CounterDelta counterDeltaFor(String deviceName, String range) {
    final pair = _snapshots[_DeltaKey(deviceName: deviceName, range: range)];
    if (pair == null || pair.current == null || pair.previous == null) return CounterDelta.empty();
    final prev = pair.previous!.counters;
    final curr = pair.current!.counters;

    int pct(int prev, int curr) {
      if (prev == 0) {
        return curr == 0 ? 0 : 100;
      }
      return (((curr - prev) / prev) * 100).round();
    }

    return CounterDelta(
      allowedPercent: pct(prev.allowed, curr.allowed),
      blockedPercent: pct(prev.blocked, curr.blocked),
    );
  }

  List<UiToplistEntry> _mergeAllowed(
      api.JsonToplistV2Response allowed, api.JsonToplistV2Response fallthrough) {
    final entries = <UiToplistEntry>[];
    entries.addAll(_convertToplist(allowed, blocked: false));
    entries.addAll(_convertToplist(fallthrough, blocked: false));

    final combined = <String, int>{};
    for (final e in entries) {
      final key = e.company ?? e.tld ?? "";
      combined[key] = (combined[key] ?? 0) + e.value;
    }
    final merged = combined.entries
        .map((e) => UiToplistEntry(e.key, e.key, false, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return merged;
  }

  List<UiToplistEntry> _convertToplist(api.JsonToplistV2Response response, {bool? blocked}) {
    final result = <UiToplistEntry>[];
    for (var bucket in response.toplist) {
      final isAllowed = bucket.action == "fallthrough" || bucket.action == "allowed";
      final isBlocked = blocked ?? !isAllowed;
      for (var entry in bucket.entries) {
        result.add(UiToplistEntry(entry.name, entry.name, isBlocked, entry.count));
      }
    }
    result.sort((a, b) => b.value.compareTo(a.value));
    return result;
  }
}

class _DeltaKey {
  final String deviceName;
  final String range;

  _DeltaKey({required this.deviceName, required this.range});

  @override
  bool operator ==(Object other) {
    return other is _DeltaKey && deviceName == other.deviceName && range == other.range;
  }

  @override
  int get hashCode => Object.hash(deviceName, range);
}

class _Snapshot {
  final List<UiToplistEntry> blocked;
  final List<UiToplistEntry> allowed;
  final StatsCounters counters;

  _Snapshot({required this.blocked, required this.allowed, required this.counters});
}

class _SnapshotPair {
  final _Snapshot? previous;
  final _Snapshot? current;
  final DateTime updatedAt;

  _SnapshotPair({required this.previous, required this.current, required this.updatedAt});
}
