import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/account/controller.dart';
import 'package:common/dragon/device/current_config.dart';
import 'package:common/dragon/filter/controller.dart';
import 'package:common/dragon/filter/selected_filters.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/filter/channel.act.dart';
import 'package:common/platform/filter/channel.pg.dart' as channel;
import 'package:dartx/dartx.dart';

import '../debounce.dart';

// This is a legacy layer that brings the new Filter concept
// to the existing platform code that used Decks/Packs.

// Initially, the app was hybrid with the business logic in Flutter,
// and UI made separately for each platform in SwiftUI / Kotlin.
// Now, we are moving to UI being made fully in Flutter.

// However, we wanted the new Filters faster since the old concept
// was problematic and buggy. So this class exposes it to for old code.
class FilterLegacy with Logging {
  late final _controller = DI.get<FilterController>();
  late final _device = DI.get<DeviceStore>();
  late final _userConfig = DI.get<CurrentConfig>();
  late final _selectedFilters = DI.get<SelectedFilters>();
  late final _knownFilters = DI.get<KnownFilters>();
  late final _ops = DI.get<channel.FilterOps>();
  late final _acc = DI.get<AccountController>();

  final _debounce = Debounce(const Duration(seconds: 1));

  FilterLegacy(Act act) {
    DI.register<channel.FilterOps>(getOps(act));
    _device.addOn(deviceChanged, onDeviceChanged);
    _selectedFilters.onChange
        .listen((it) => onSelectedFiltersChanged(it, Markers.filter));
    _userConfig.onChange.listen((it) => onUserConfigChanged(it));
    // todo: default value at first start of new account
  }

  Future<void> onDeviceChanged(Marker m) async {
    return await log(m).trace("onDeviceChangedLegacy", (m) async {
      final lists = _device.lists;
      if (lists != null) {
        await _acc.start();
        // Read user config from device v2 when it is ready
        // Set it and it will reload FilterController
        // That one will update SelectedFilters
        _userConfig.now = UserFilterConfig(lists.toSet(), {});
      }
    });
  }

  // Push it to pigeon, together with KnownFilters converted and the tags
  onSelectedFiltersChanged(List<FilterSelection> selected, Marker m) {
    log(m).i("updating filters legacy, selected: ${selected.length}");

    _ops.doFiltersChanged(_knownFilters.get().map((it) {
      return channel.Filter(
        filterName: it.filterName,
        options: it.options.map((e) => e.optionName).toList(),
      );
    }).toList());

    _ops.doFilterSelectionChanged(selected.map((it) {
      return channel.Filter(
        filterName: it.filterName,
        options: it.options,
      );
    }).toList());

    _ops.doListToTagChanged(_controller.getListsToTags().map((key, value) {
      return MapEntry(key, value);
    }));
  }

  enableFilter(String filterName, Marker m) async {
    log(m).i("enabling filter $filterName");

    final known = _knownFilters
        .get()
        .firstOrNullWhere((it) => it.filterName == filterName);
    final newFilter =
        FilterSelection(filterName, [known!.options.first.optionName]);

    final was = _selectedFilters.now;
    final selected = was.toList();
    final index = selected.indexWhere((it) => it.filterName == filterName);
    if (index != -1) {
      selected[index] = newFilter;
    } else {
      selected.add(newFilter);
    }
    _selectedFilters.now = selected;

    try {
      final config = await _controller.getConfig(_selectedFilters.now, m);
      await log(m).trace("enableFilterLegacy", (m) async {
        log(m).pair("lists", config.lists);
        _userConfig.now = config;
        // v2 api will be updated by the callback below
      });
    } catch (e) {
      _selectedFilters.now = was;
    }
  }

  disableFilter(String filterName, Marker m) async {
    log(m).i("disabling filter $filterName");

    final was = _selectedFilters.now;
    final selected = was.toList();
    selected.removeWhere((it) => it.filterName == filterName);
    _selectedFilters.now = selected;

    try {
      final config = await _controller.getConfig(_selectedFilters.now, m);
      await log(m).trace("disableFilterLegacy", (m) async {
        log(m).pair("lists", config.lists);
        _userConfig.now = config;
        // v2 api will be updated by the callback below
      });
    } catch (e) {
      _selectedFilters.now = was;
    }
  }

  toggleFilterOption(String filterName, String option, Marker m) async {
    log(m).i("toggling filter $filterName option $option");

    final known = _knownFilters
        .get()
        .firstOrNullWhere((it) => it.filterName == filterName);
    if (known == null) {
      log(m).i("filter $filterName not found");
      return;
    }

    final newFilter = FilterSelection(filterName, [option]);

    final was = _selectedFilters.now;
    final selected = was.toList();
    final index = selected.indexWhere((it) => it.filterName == filterName);
    if (index != -1) {
      final old = selected[index];
      if (old.options.contains(option)) {
        selected[index] = FilterSelection(filterName, old.options - [option]);
      } else {
        selected[index] = FilterSelection(filterName, old.options + [option]);
      }
    } else {
      selected.add(newFilter);
    }
    _selectedFilters.now = selected;

    try {
      final config = await _controller.getConfig(_selectedFilters.now, m);
      await log(m).trace("toggleFilterOptionLegacy", (m) async {
        log(m).pair("lists", config.lists);
        _userConfig.now = config;
        // v2 api will be updated by the callback below
      });
    } catch (e) {
      _selectedFilters.now = was;
    }
  }

  onUserConfigChanged(UserFilterConfig? config) {
    if (config == null) return;
    final lists = config.lists;
    if (lists == _device.lists?.toSet()) return;
    if (lists.isEmpty) return; // Skip setting empty list, not supported by v2
    // v2 will force the default config on empty list.
    // Instead we assume FilterController will set the defaults shortly after.

    _debounce.run(() async {
      // UserConfigs got updated by FilterController, push to v2 api
      await _device.setLists(lists.toList(), Markers.filter);
    });
  }
}
