import 'package:collection/collection.dart';
import 'package:mobx/mobx.dart';

import '../device/device.dart';
import '../stage/stage.dart';
import '../timer/timer.dart';
import '../util/config.dart';
import '../util/cooldown.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'journal.g.dart';

const _timerKey = "journalRefresh";

extension JournalFilterExt on JournalFilter {
  // Providing null means "no change" (existing filter is used)
  // To reset a query/device, provide an empty string.
  JournalFilter updateOnly({
    JournalFilterType? showOnly,
    String? searchQuery,
    String? deviceName,
    bool? sortNewestFirst,
  }) {
    return JournalFilter(
      showOnly: showOnly ?? this.showOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      deviceName: deviceName ?? this.deviceName,
      sortNewestFirst: sortNewestFirst ?? this.sortNewestFirst,
    );
  }

  string() {
    return "showOnly: $showOnly, searchQuery: $searchQuery, deviceName: $deviceName, sortNewestFirst: $sortNewestFirst";
  }

  List<JournalEntry> apply(List<JournalEntry> entries) {
    List<JournalEntry> filtered = entries;

    // Apply search term
    final q = searchQuery;
    if (q.length > 1) {
      filtered = filtered.where((e) => e.domainName.contains(q)).toList();
    }

    // Apply device
    final d = deviceName;
    if (d.isNotEmpty) {
      filtered = filtered.where((e) => e.deviceName == deviceName).toList();
    }

    // Apply filtering
    if (showOnly == JournalFilterType.showBlocked) {
      filtered = filtered
          .where((e) =>
              e.type == JournalEntryType.blocked ||
              e.type == JournalEntryType.blockedDenied)
          .toList();
    } else if (showOnly == JournalFilterType.showPassed) {
      filtered = filtered
          .where((e) =>
              e.type == JournalEntryType.passed ||
              e.type == JournalEntryType.passedAllowed)
          .toList();
    }

    // Apply sorting
    if (sortNewestFirst) {
      // It should be OK to sort ISO timestamps as strings
      filtered.sort((a, b) => b.time.compareTo(a.time));
    } else {
      filtered.sort((a, b) => b.requests.compareTo(a.requests));
    }

    return filtered;
  }
}

JournalFilter _noFilter = JournalFilter(
    showOnly: JournalFilterType.showAll,
    searchQuery: "", // Empty string means "no query"
    deviceName: "", // Empty string means "all devices"
    sortNewestFirst: true);

class JournalStore = JournalStoreBase with _$JournalStore;

abstract class JournalStoreBase with Store, Traceable, Dependable, Cooldown {
  late final _ops = dep<JournalOps>();
  late final _json = dep<JournalJson>();
  late final _device = dep<DeviceStore>();
  late final _stage = dep<StageStore>();
  late final _timer = dep<TimerService>();

  JournalStoreBase() {
    _device.addOn(deviceChanged, updateJournalFreq);
    _stage.addOnValue(routeChanged, onRouteChanged);
    _timer.addHandler(_timerKey, onTimerFired);

    reactionOnStore((_) => filteredEntries, (entries) async {
      _ops.doReplaceEntries(entries);
    });

    reactionOnStore((_) => filter, (filter) async {
      _ops.doFilterChanged(filter);
    });

    reactionOnStore((_) => filterSorting, (filter) async {
      _ops.doReplaceEntries(filteredEntries);
    });

    reactionOnStore((_) => devices, (devices) async {
      _ops.doDevicesChanged(devices);
    });
  }

  @override
  attach(Act act) {
    depend<JournalOps>(getOps(act));
    depend<JournalJson>(JournalJson());
    depend<JournalStore>(this as JournalStore);
  }

  @observable
  JournalFilter filter = _noFilter;

  @observable
  List<JournalEntry> allEntries = [];

  @computed
  List<JournalEntry> get filteredEntries => filter.apply(allEntries);

  @computed
  // Changing list sorting doesn't trigger mobx reaction, need to be explicit
  bool get filterSorting => filter.sortNewestFirst;

  @computed
  List<String> get devices =>
      allEntries.map((e) => e.deviceName).toSet().toList();

  @observable
  bool refreshEnabled = false;

  @observable
  DateTime lastRefresh = DateTime(0);

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      final entries = await _json.getEntries(trace);
      final grouped = groupBy(entries, (e) => "${e.action}${e.domainName}");

      allEntries = grouped.values.map((value) {
        // Assuming items are ordered by most recent first
        return _convertEntry(value.first, value.length);
      }).toList();
    });
  }

  @action
  Future<void> onTimerFired(Trace parentTrace) async {
    return await traceWith(parentTrace, "onTimerFired", (trace) async {
      final route = _stage.route;
      if (!route.isForeground()) {
        _stopTimer();
        return;
      }

      if (!_stage.route.isTab(StageTab.activity)) {
        _stopTimer();
        return;
      }

      if (refreshEnabled) {
        try {
          await fetch(trace);
          _rescheduleTimer();
        } on Exception catch (_) {
          _rescheduleTimer();
        }
      }
    });
  }

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (!route.isForeground()) return;
    if (!route.isBecameTab(StageTab.activity)) return;
    await updateJournalFreq(parentTrace);
  }

  @action
  Future<void> enableRefresh(Trace parentTrace) async {
    return await traceWith(parentTrace, "enableRefresh", (trace) async {
      refreshEnabled = true;
      await onTimerFired(trace);
    });
  }

  @action
  Future<void> disableRefresh(Trace parentTrace) async {
    return await traceWith(parentTrace, "disableRefresh", (trace) async {
      refreshEnabled = false;
      _stopTimer();
    });
  }

  @action
  Future<void> updateJournalFreq(Trace parentTrace) async {
    return await traceWith(parentTrace, "updateJournalFreq", (trace) async {
      final enabled = _device.retention?.isEnabled() ?? false;
      if (enabled && _stage.route.isTab(StageTab.activity)) {
        await enableRefresh(trace);
      } else if (!enabled) {
        await disableRefresh(trace);
      }
    });
  }

  _rescheduleTimer() {
    _timer.set(_timerKey, DateTime.now().add(cfg.journalRefreshCooldown));
  }

  _stopTimer() {
    _timer.unset(_timerKey);
  }

  @action
  Future<void> updateFilter(
    Trace parentTrace, {
    JournalFilterType? showOnly,
    String? searchQuery,
    String? deviceName,
    bool? sortNewestFirst,
  }) async {
    return await traceWith(parentTrace, "updateFilter", (trace) async {
      final newFilter = filter.updateOnly(
        showOnly: showOnly,
        searchQuery: searchQuery,
        deviceName: deviceName,
        sortNewestFirst: sortNewestFirst,
      );

      if (newFilter.searchQuery != filter.searchQuery ||
          newFilter.deviceName != filter.deviceName ||
          newFilter.showOnly != filter.showOnly ||
          newFilter.sortNewestFirst != filter.sortNewestFirst) {
        filter = newFilter;
        trace.addAttribute("filter", filter.string());
      }
    });
  }

  JournalEntry _convertEntry(JsonJournalEntry jsonEntry, int requests) {
    return JournalEntry(
      domainName: jsonEntry.domainName,
      type: _convertType(jsonEntry),
      time: jsonEntry.timestamp,
      requests: requests,
      deviceName: jsonEntry.deviceName,
      list: jsonEntry.list,
    );
  }

  JournalEntryType _convertType(JsonJournalEntry e) {
    if (e.action == "block" && e.list == _device.deviceTag) {
      return JournalEntryType.blockedDenied;
    } else if (e.action == "allow" && e.list == _device.deviceTag) {
      return JournalEntryType.passedAllowed;
    } else if (e.action == "block") {
      return JournalEntryType.blocked;
    } else {
      return JournalEntryType.passed;
    }
  }
}
