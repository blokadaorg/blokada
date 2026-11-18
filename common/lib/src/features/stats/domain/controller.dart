import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/stats/stats.dart';

/// The period Privacy Pulse shows: the last 24 hours or the last 7 days.
enum ToplistRange { daily, weekly }

extension ToplistRangeApi on ToplistRange {
  /// The range as the stats and toplist endpoints name it.
  String get api => this == ToplistRange.daily ? "24h" : "7d";
}

/// Where a section of the stats screens is: still loading, showing data,
/// loaded with nothing to show, or failed (the screen offers a retry).
enum StatsStatus { loading, ready, empty, error }

/// One section's state. [data] is the last data loaded; it stays while the
/// section refreshes, so screens don't blank, and after a failed refresh.
class StatsSection<T> {
  final StatsStatus status;
  final T? data;

  const StatsSection(this.status, [this.data]);

  const StatsSection.loading([this.data]) : status = StatsStatus.loading;

  bool get isError => status == StatsStatus.error;

  StatsSection<T> withStatus(StatsStatus status) => StatsSection(status, data);
}

class StatsSectionValue<T> extends Value<StatsSection<T>> {
  StatsSectionValue(StatsSection<T> Function() load) : super(load: load);
}

class ToplistRangeValue extends Value<ToplistRange> {
  ToplistRangeValue() : super(load: () => ToplistRange.daily);
}

class CollectingValue extends Value<bool> {
  CollectingValue() : super(load: () => false);
}

/// The Privacy Pulse chart numbers for the selected range.
class PulseCounters {
  final StatsCounters counters;

  /// Change against the previous period; null when it could not be loaded.
  final CounterDelta? delta;

  /// False while the comparison is still loading.
  final bool deltaReady;

  /// Allowed requests per day, for the 7-day range only.
  final DailySeries? sparkline;

  const PulseCounters({
    required this.counters,
    required this.delta,
    required this.deltaReady,
    required this.sparkline,
  });
}

/// The Privacy Pulse toplists for the selected range, with rank changes.
class PulseToplists {
  final List<UiToplistEntry> entries;
  final List<ToplistDelta>? blockedDeltas;
  final List<ToplistDelta>? allowedDeltas;

  const PulseToplists({
    required this.entries,
    required this.blockedDeltas,
    required this.allowedDeltas,
  });

  List<UiToplistEntry> get blocked => entries.where((e) => e.blocked).take(12).toList();

  List<UiToplistEntry> get allowed => entries.where((e) => !e.blocked).take(12).toList();
}

/// The latest few blocked and allowed requests, for Privacy Pulse.
class RecentPreview {
  final List<UiJournalEntry> blocked;
  final List<UiJournalEntry> allowed;

  const RecentPreview({required this.blocked, required this.allowed});
}

/// The sections a screen can ask to retry.
enum StatsPart { stats, counters, toplists, recent }

class _Deltas {
  final CounterDelta? counter;
  final List<ToplistDelta>? blocked;
  final List<ToplistDelta>? allowed;

  const _Deltas({this.counter, this.blocked, this.allowed});
}

/// Owns the stats Home and Privacy Pulse show: fetching, refresh and the
/// selected range, with a loading, ready, empty or error state per section.
///
/// Screens used to start their own fetches, from eight places, and kept the
/// results in widget state with no error state, so a failed load looked like
/// "no data" and Home and Pulse could disagree. Here both read the same
/// sections, built from [StatsStore] (still the data source), and screens
/// only draw them.
class StatsController with Logging, Actor {
  /// How often Home's counter refreshes while it is visible.
  static const homeRefreshInterval = Duration(seconds: 30);

  late final _store = Core.get<StatsStore>();
  late final _deltaStore = Core.get<StatsDeltaStore>();
  late final _device = Core.get<DeviceStore>();
  late final _journal = Core.get<JournalActor>();
  late final _journalEntries = Core.get<JournalEntriesValue>();

  /// The device's stats: Home's counter, Pulse's charts and all-time totals.
  late final stats = StatsSectionValue<UiStats>(_statsFromStore);

  /// Pulse's chart numbers for [range].
  final counters = StatsSectionValue<PulseCounters>(() => const StatsSection.loading());

  /// Pulse's toplists for [range].
  final toplists = StatsSectionValue<PulseToplists>(() => const StatsSection.loading());

  /// Pulse's recent activity preview.
  final recent = StatsSectionValue<RecentPreview>(() => const StatsSection.loading());

  /// The range Pulse shows.
  final range = ToplistRangeValue();

  /// True from the moment activity logging is turned on here until the first
  /// results show up, so empty lists say they are coming instead of that
  /// there is nothing. Not kept across restarts.
  final collecting = CollectingValue();

  Timer? _homeTimer;
  int _pulseViews = 0;
  StreamSubscription? _journalSub;
  String? _lastAlias;

  int _statsGen = 0;
  int _countersGen = 0;
  int _toplistsGen = 0;
  Future<void>? _toplistsInFlight;
  bool _recentLoading = false;
  bool _recentPending = false;

  // Weekly counters come from their own fetch; daily ones from [stats].
  StatsSection<StatsCounters> _weekCounters = const StatsSection.loading();
  DailySeries? _weekSparkline;
  // Taken right after this controller's own toplist fetch, so a later
  // republish (deltas landing) can't pick up another range's entries.
  List<UiToplistEntry> _toplistEntries = const [];
  final _deltas = <ToplistRange, _Deltas>{};

  @override
  Future<void> onCreate(Marker m) async {
    _device.addOn(deviceChanged, _onDeviceChanged);
  }

  /// Home's counter calls this when it should (or should no longer) refresh:
  /// protection on, app in the foreground and Home not covered.
  void setHomeRefresh(bool enabled) {
    if (enabled) {
      if (_homeTimer != null) return;
      _lastAlias = _device.deviceAlias;
      unawaited(_loadStats(Markers.stats, force: false));
      _homeTimer = Timer.periodic(homeRefreshInterval, (_) {
        unawaited(_loadStats(Markers.stats, force: true));
      });
    } else {
      _homeTimer?.cancel();
      _homeTimer = null;
    }
  }

  /// Privacy Pulse opened: load its sections for [initialRange] (24h when
  /// null) and keep the recent activity in step with the journal.
  Future<void> openPulse(Marker m, {ToplistRange? initialRange}) async {
    _pulseViews++;
    range.now = initialRange ?? ToplistRange.daily;
    _lastAlias = _device.deviceAlias;
    _journalSub ??= _journalEntries.onChange.listen((_) {
      unawaited(_loadRecent(Markers.stats));
    });
    _publishCounters();
    await _loadPulse(m, force: false);
  }

  /// Privacy Pulse closed.
  void closePulse() {
    if (_pulseViews > 0) _pulseViews--;
    if (_pulseViews > 0) return;
    _journalSub?.cancel();
    _journalSub = null;
  }

  /// Pull to refresh on Privacy Pulse: reload everything, skipping caches.
  Future<void> refreshPulse(Marker m) async {
    return await log(m).trace("refreshPulse", (m) async {
      await Future.wait([_loadPulse(m, force: true), _refreshJournal(m)]);
    });
  }

  /// Switches Pulse to [next] and loads its numbers and toplists. When it
  /// is already selected, waits for the toplists still loading.
  Future<void> setRange(Marker m, ToplistRange next) async {
    if (range.now == next) {
      final pending = _toplistsInFlight;
      if (pending != null) await pending;
      return;
    }

    range.now = next;
    _publishCounters();
    await Future.wait([_loadCounters(m, force: true), _loadDeltas(m, next), _loadToplists(m)]);
  }

  /// Turns activity logging on (retention "24h"). Logging is off by default;
  /// this is the one-tap opt-in from the logging-off preview.
  Future<void> enableLogging(Marker m) async {
    return await log(m).trace("enableLogging", (m) async {
      collecting.now = true;
      try {
        await _device.setRetention("24h", m);
      } catch (_) {
        collecting.now = false;
        rethrow;
      }
    });
  }

  /// Retries a section, usually one showing an error.
  Future<void> retry(Marker m, StatsPart part) async {
    switch (part) {
      case StatsPart.stats:
        await _loadStats(m, force: true);
      case StatsPart.counters:
        await _loadCounters(m, force: true);
      case StatsPart.toplists:
        await _loadToplists(m);
      case StatsPart.recent:
        await _loadRecent(m);
    }
  }

  Future<void> _loadPulse(Marker m, {required bool force}) async {
    await Future.wait([
      _loadStats(m, force: force),
      if (range.now == ToplistRange.weekly) _loadCounters(m, force: force),
      _loadDeltas(m, range.now),
      _loadToplists(m),
      _loadRecent(m),
    ]);
  }

  Future<void> _onDeviceChanged(Marker m) async {
    if (collecting.now && _device.retention != "24h") collecting.now = false;
    final alias = _device.deviceAlias;
    if (alias.isEmpty || alias == _lastAlias) return;
    _lastAlias = alias;

    // A new name means different stats; reload what is on screen.
    if (_pulseViews > 0) {
      await _loadPulse(m, force: true);
    } else if (_homeTimer != null) {
      await _loadStats(m, force: true);
    }
  }

  StatsSection<UiStats> _statsFromStore() {
    // The store skips fetches until the device has a name; keep loading.
    if (!_store.hasStats) return const StatsSection.loading();
    final s = _store.stats;
    return StatsSection(s.dayTotal == 0 ? StatsStatus.empty : StatsStatus.ready, s);
  }

  /// The device was renamed while a load for [deviceName] was in flight: its
  /// result belongs to the old name, and the rename starts a new load.
  bool _renamed(String deviceName) => _device.deviceAlias != deviceName;

  Future<void> _loadStats(Marker m, {required bool force}) async {
    final gen = ++_statsGen;
    final deviceName = _device.deviceAlias;
    final week = _pulseViews > 0;
    stats.now = stats.now.withStatus(StatsStatus.loading);
    _publishCounters();
    try {
      await _store.fetchDay(m, force: force);
      if (week) await _store.fetchWeek(m, force: force);
      if (gen != _statsGen || _renamed(deviceName)) return;
      stats.now = _statsFromStore();
    } catch (e, s) {
      log(m).e(msg: "stats: fetch failed", err: e, stack: s);
      if (gen != _statsGen || _renamed(deviceName)) return;
      stats.now = stats.now.withStatus(StatsStatus.error);
    }
    _publishCounters();
  }

  Future<void> _loadCounters(Marker m, {required bool force}) async {
    final selected = range.now;
    // The 24h numbers are the ones Home shows: the same stats, not a refetch.
    if (selected == ToplistRange.daily) return await _loadStats(m, force: force);

    final gen = ++_countersGen;
    final deviceName = _device.deviceAlias;
    _weekCounters = _weekCounters.withStatus(StatsStatus.loading);
    _publishCounters();
    try {
      final counters = await _store.countersForRange(selected.api, m, force: force);
      final sparkline = await _store.allowedDailySeries(m, days: 7, force: force);
      if (gen != _countersGen || _renamed(deviceName)) return;
      _weekCounters = StatsSection(
        counters.total == 0 ? StatsStatus.empty : StatsStatus.ready,
        counters,
      );
      _weekSparkline = sparkline;
      // The weekly fetch also refreshes the store's stats.
      if (_store.hasStats) stats.now = _statsFromStore();
    } catch (e, s) {
      log(m).e(msg: "stats: weekly counters failed", err: e, stack: s);
      if (gen != _countersGen || _renamed(deviceName)) return;
      _weekCounters = _weekCounters.withStatus(StatsStatus.error);
    }
    _publishCounters();
  }

  /// Rank changes and the counter comparison. Optional extras: a failure
  /// only hides them.
  Future<void> _loadDeltas(Marker m, ToplistRange selected) async {
    final deviceName = _device.deviceAlias;
    if (deviceName.isEmpty) return;

    _deltas.remove(selected);
    _publishCounters();
    _Deltas result;
    try {
      await _deltaStore.refresh(m, deviceName: deviceName, range: selected.api, force: false);
      result = _Deltas(
        counter: _deltaStore.counterDeltaFor(deviceName, selected.api),
        blocked: _deltaStore.deltasFor(deviceName, selected.api, blocked: true),
        allowed: _deltaStore.deltasFor(deviceName, selected.api, blocked: false),
      );
    } catch (e, s) {
      log(m).e(msg: "stats: deltas failed", err: e, stack: s);
      result = const _Deltas();
    }
    if (_renamed(deviceName)) return;
    _deltas[selected] = result;
    _publishCounters();
    _publishToplists(toplists.now.status);
  }

  Future<void> _loadToplists(Marker m) {
    final selected = range.now;
    final gen = ++_toplistsGen;
    // Entries are for one range; never show the other range's while loading.
    toplists.now = const StatsSection.loading();

    final future = () async {
      final deviceName = _device.deviceAlias;
      if (deviceName.isEmpty) return;
      try {
        await _store.fetchToplists(m, range: selected.api);
        if (gen != _toplistsGen || _renamed(deviceName)) return;
        _toplistEntries = _store.stats.toplist;
        if (_toplistEntries.isNotEmpty) collecting.now = false;
        _publishToplists(_toplistEntries.isEmpty ? StatsStatus.empty : StatsStatus.ready);
      } catch (e, s) {
        log(m).e(msg: "stats: toplists failed", err: e, stack: s);
        if (gen != _toplistsGen || _renamed(deviceName)) return;
        toplists.now = const StatsSection(StatsStatus.error);
      }
    }();

    _toplistsInFlight = future;
    return future.whenComplete(() {
      if (_toplistsInFlight == future) _toplistsInFlight = null;
    });
  }

  Future<void> _loadRecent(Marker m) async {
    final deviceName = _device.deviceAlias;
    if (deviceName.isEmpty) return;
    // The journal changed mid-load: load again once this one is done.
    if (_recentLoading) {
      _recentPending = true;
      return;
    }

    _recentLoading = true;
    recent.now = recent.now.withStatus(StatsStatus.loading);
    try {
      final results = await Future.wait([
        _journal.fetchPreview(m, action: UiJournalAction.block, deviceName: deviceName, limit: 5),
        _journal.fetchPreview(m, action: UiJournalAction.allow, deviceName: deviceName, limit: 5),
      ]);
      final preview = RecentPreview(blocked: results[0], allowed: results[1]);
      final empty = preview.blocked.isEmpty && preview.allowed.isEmpty;
      if (!empty) collecting.now = false;
      if (!_renamed(deviceName)) {
        recent.now = StatsSection(empty ? StatsStatus.empty : StatsStatus.ready, preview);
      }
    } catch (e, s) {
      log(m).e(msg: "stats: recent activity failed", err: e, stack: s);
      if (!_renamed(deviceName)) recent.now = recent.now.withStatus(StatsStatus.error);
    } finally {
      _recentLoading = false;
    }

    if (_recentPending) {
      _recentPending = false;
      await _loadRecent(m);
    }
  }

  Future<void> _refreshJournal(Marker m) async {
    try {
      // A new journal reloads the recent activity through [_journalSub].
      await _journal.fetch(m, tag: null);
    } catch (e, s) {
      log(m).e(msg: "stats: journal refresh failed", err: e, stack: s);
      await _loadRecent(m);
    }
  }

  void _publishCounters() {
    final selected = range.now;
    final deltas = _deltas[selected];

    final StatsSection<StatsCounters> source;
    if (selected == ToplistRange.daily) {
      final s = stats.now;
      final day = s.data;
      source = StatsSection(
        s.status,
        day == null
            ? null
            : StatsCounters(allowed: day.dayAllowed, blocked: day.dayBlocked, total: day.dayTotal),
      );
    } else {
      source = _weekCounters;
    }

    final data = source.data;
    counters.now = StatsSection(
      source.status,
      data == null
          ? null
          : PulseCounters(
              counters: data,
              delta: deltas?.counter,
              deltaReady: deltas != null,
              sparkline: selected == ToplistRange.weekly ? _weekSparkline : null,
            ),
    );
  }

  void _publishToplists(StatsStatus status) {
    if (status == StatsStatus.loading || status == StatsStatus.error) return;
    final deltas = _deltas[range.now];
    toplists.now = StatsSection(
      status,
      PulseToplists(
        entries: _toplistEntries,
        blockedDeltas: deltas?.blocked,
        allowedDeltas: deltas?.allowed,
      ),
    );
  }
}

class StatsControllerModule with Module {
  @override
  onCreateModule() async {
    await register(StatsController());
  }
}
