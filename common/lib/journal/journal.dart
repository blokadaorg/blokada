import 'package:collection/collection.dart';
import 'package:mobx/mobx.dart';

import '../env/env.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'journal.g.dart';

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

abstract class JournalStoreBase with Store, Traceable {
  late final _json = di<JournalJson>();
  late final _env = di<EnvStore>();

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
    if (e.action == "block" && e.list == _env.deviceTag) {
      return JournalEntryType.blockedDenied;
    } else if (e.action == "allow" && e.list == _env.deviceTag) {
      return JournalEntryType.passedAllowed;
    } else if (e.action == "block") {
      return JournalEntryType.blocked;
    } else {
      return JournalEntryType.passed;
    }
  }
}

class JournalBinder with JournalEvents, Traceable {
  late final _store = di<JournalStore>();
  late final _ops = di<JournalOps>();
  late final _env = di<EnvStore>();

  JournalBinder() {
    JournalEvents.setup(this);
    _init();
  }

  JournalBinder.forTesting() {
    _init();
  }

  _init() {
    _onJournalChanged();
    _onFilterChanged();
    _onFilterSortingChanged();
    _onDevicesChanged();
    _onDeviceNameChanged();
  }

  @override
  Future<void> onSearch(String query) async {
    await traceAs("onSearch", (trace) async {
      await _store.updateFilter(trace, searchQuery: query);
    });
  }

  @override
  Future<void> onShowForDevice(String deviceName) async {
    await traceAs("onShowForDevice", (trace) async {
      await _store.updateFilter(trace, deviceName: deviceName);
    });
  }

  @override
  Future<void> onShowOnly(bool showBlocked, bool showPassed) async {
    await traceAs("onShowOnly", (trace) async {
      await _store.updateFilter(
        trace,
        showOnly: showBlocked && showPassed
            ? JournalFilterType.showAll
            : showBlocked
                ? JournalFilterType.showBlocked
                : JournalFilterType.showPassed,
      );
    });
  }

  @override
  Future<void> onSort(bool newestFirst) async {
    await traceAs("onSort", (trace) async {
      await _store.updateFilter(trace, sortNewestFirst: newestFirst);
    });
  }

  @override
  Future<void> onLoadMoreHistoricEntries() async {
    await traceAs("onLoadMoreHistoricEntries", (trace) async {
      throw Exception("Loading historic entries not implemented");
    });
  }

  @override
  Future<void> onStartListening() async {
    await traceAs("onStartListening", (trace) async {
      _ops.doReplaceEntries(_store.filteredEntries);
      _ops.doFilterChanged(_store.filter);
    });
  }

  _onJournalChanged() {
    reaction((_) => _store.filteredEntries, (entries) async {
      await traceAs("onJournalChanged", (trace) async {
        _ops.doReplaceEntries(entries);
      });
    });
  }

  _onFilterChanged() {
    reaction((_) => _store.filter, (filter) async {
      await traceAs("onFilterChanged", (trace) async {
        _ops.doFilterChanged(filter);
      });
    });
  }

  _onFilterSortingChanged() {
    reaction((_) => _store.filterSorting, (filter) async {
      await traceAs("onFilterSortingChanged", (trace) async {
        _ops.doReplaceEntries(_store.filteredEntries);
      });
    });
  }

  _onDevicesChanged() {
    reaction((_) => _store.devices, (devices) async {
      await traceAs("onDevicesChanged", (trace) async {
        _ops.doDevicesChanged(devices);
      });
    });
  }

  _onDeviceNameChanged() {
    reaction((_) => _env.deviceName, (name) async {
      await traceAs("onDeviceNameChanged", (trace) async {
        // Default to show journal only for the current device
        _store.updateFilter(trace, deviceName: _env.deviceName);
      });
    });
  }
}

Future<void> init() async {
  di.registerSingleton<JournalJson>(JournalJson());
  di.registerSingleton<JournalOps>(JournalOps());
  di.registerSingleton<JournalStore>(JournalStore());
  JournalBinder();
}
