import 'package:collection/collection.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/journal/channel.pg.dart';
import 'package:mobx/mobx.dart';

import '../../util/cooldown.dart';
import '../../util/mobx.dart';
import '../device/device.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import 'channel.act.dart';
import 'json.dart';

part 'journal.g.dart';

const _timerKey = "journalRefresh";

extension JournalEntryExtension on JournalEntry {
  bool isBlocked() {
    return type == JournalEntryType.blocked ||
        type == JournalEntryType.blockedDenied;
  }
}

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
    if (showOnly == JournalFilterType.blocked) {
      filtered = filtered
          .where((e) =>
              e.type == JournalEntryType.blocked ||
              e.type == JournalEntryType.blockedDenied)
          .toList();
    } else if (showOnly == JournalFilterType.passed) {
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
    showOnly: JournalFilterType.all,
    searchQuery: "", // Empty string means "no query"
    deviceName: "", // Empty string means "all devices"
    sortNewestFirst: true);

class JournalStore = JournalStoreBase with _$JournalStore;

abstract class JournalStoreBase with Store, Logging, Actor, Cooldown {
  late final _ops = DI.get<JournalOps>();
  late final _json = DI.get<JournalJson>();
  late final _device = DI.get<DeviceStore>();
  late final _stage = DI.get<StageStore>();
  late final _scheduler = DI.get<Scheduler>();

  JournalStoreBase() {
    _device.addOn(deviceChanged, updateJournalFreq);
    _stage.addOnValue(routeChanged, onRouteChanged);

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
  onRegister(Act act) {
    this.act = act;
    DI.register<JournalOps>(getOps(act));
    DI.register<JournalJson>(JournalJson());
    DI.register<JournalStore>(this as JournalStore);
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

  bool frequentRefresh = false;

  @override
  Future<void> onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      if (act.isFamily) return;

      // Default to show journal only for the current device
      await updateFilter(deviceName: _device.deviceAlias, m);
    });
  }

  @action
  Future<void> fetch(Marker m) async {
    return await log(m).trace("fetch", (m) async {
      final entries = await _json.getEntries(m);
      final grouped = groupBy(entries, (e) => "${e.action}${e.domainName}");

      allEntries = grouped.values.map((value) {
        // Assuming items are ordered by most recent first
        return _convertEntry(value.first, value.length);
      }).toList();
    });
  }

  @action
  Future<bool> onTimerFired(Marker m) async {
    final route = _stage.route;
    if (!route.isForeground()) {
      _stopTimer(m);
      return false;
    }

    final isActivity = _stage.route.isTab(StageTab.activity);
    final isHome = _stage.route.isTab(StageTab.home);
    final isLinkModal = route.modal == StageModal.accountLink;

    if (!act.isFamily && !isActivity) {
      _stopTimer(m);
      return false;
    }

    if (act.isFamily && !isHome && !isActivity) {
      _stopTimer(m);
      return false;
    }

    if (refreshEnabled) {
      final cooldown = (isActivity || isLinkModal || frequentRefresh)
          ? cfg.refreshVeryFrequent
          : cfg.refreshOnHome;
      try {
        await fetch(m);
        _rescheduleTimer(m, cooldown);
      } on Exception catch (_) {
        _rescheduleTimer(m, cooldown);
      }
    }
    return false;
  }

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isForeground()) {
      log(m).i("journal: route not foreground");
      return;
    }

    final isActivity = route.isTab(StageTab.activity);
    final isHome = route.isTab(StageTab.home);
    final isLinkModal = route.modal == StageModal.accountLink;
    if (!act.isFamily && !isActivity) return;
    if (act.isFamily && !isActivity && !isHome && !isLinkModal) return;
    await updateJournalFreq(m);
  }

  @action
  Future<void> enableRefresh(Marker m) async {
    return await log(m).trace("enableRefresh", (m) async {
      refreshEnabled = true;
      await onTimerFired(m);
    });
  }

  @action
  Future<void> disableRefresh(Marker m) async {
    return await log(m).trace("disableRefresh", (m) async {
      refreshEnabled = false;
      _stopTimer(m);
    });
  }

  @action
  Future<void> setFrequentRefresh(Marker m, bool frequent) async {
    return await log(m).trace("frequentRefresh", (m) async {
      frequentRefresh = frequent;
      if (frequent) {
        refreshEnabled = true;
        await onTimerFired(m);
      }
    });
  }

  @action
  Future<void> updateJournalFreq(Marker m) async {
    return await log(m).trace("updateJournalFreq", (m) async {
      final on = _device.retention?.isEnabled() ?? false;
      log(m).pair("retention", on);
      if (on && _stage.route.isTab(StageTab.activity)) {
        await enableRefresh(m);
      } else if (on && act.isFamily && _stage.route.isTab(StageTab.home)) {
        await enableRefresh(m);
      } else if (!on) {
        await disableRefresh(m);
      }
    });
  }

  _rescheduleTimer(Marker m, Duration cooldown) {
    _scheduler.addOrUpdate(Job(
      _timerKey,
      m,
      before: DateTime.now().add(cooldown),
      callback: onTimerFired,
    ));
  }

  _stopTimer(Marker m) => _scheduler.stop(m, _timerKey);

  @action
  Future<void> updateFilter(
    Marker m, {
    JournalFilterType? showOnly,
    String? searchQuery,
    String? deviceName,
    bool? sortNewestFirst,
  }) async {
    return await log(m).trace("updateFilter", (m) async {
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
        log(m).pair("filter", filter.string());
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
