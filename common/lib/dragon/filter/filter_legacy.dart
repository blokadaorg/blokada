import 'package:common/common/model.dart';
import 'package:common/device/device.dart';
import 'package:common/dragon/account/controller.dart';
import 'package:common/dragon/device/current_config.dart';
import 'package:common/dragon/filter/controller.dart';
import 'package:common/dragon/filter/selected_filters.dart';
import 'package:common/filter/channel.act.dart';
import 'package:common/filter/channel.pg.dart' as channel;
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:dartx/dartx.dart';

import '../debounce.dart';

// This is a legacy layer that brings the new Filter concept
// to the existing platform code that used Decks/Packs.

// Initially, the app was hybrid with the business logic in Flutter,
// and UI made separately for each platform in SwiftUI / Kotlin.
// Now, we are moving to UI being made fully in Flutter.

// However, we wanted the new Filters faster since the old concept
// was problematic and buggy. So this class exposes it to for old code.
class FilterLegacy with Traceable, TraceOrigin {
  late final _controller = dep<FilterController>();
  late final _device = dep<DeviceStore>();
  late final _userConfig = dep<CurrentConfig>();
  late final _selectedFilters = dep<SelectedFilters>();
  late final _knownFilters = dep<KnownFilters>();
  late final _ops = dep<channel.FilterOps>();
  late final _acc = dep<AccountController>();

  final _debounce = Debounce(const Duration(seconds: 1));
  final _debounceSwitch = Debounce(const Duration(milliseconds: 200));

  FilterLegacy(Act act) {
    depend<channel.FilterOps>(getOps(act));
    _device.addOn(deviceChanged, onDeviceChanged);
    _selectedFilters.onChange.listen((it) => onSelectedFiltersChanged(it));
    _userConfig.onChange.listen((it) => onUserConfigChanged(it));
    // todo: default value at first start of new account
  }

  Future<void> onDeviceChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onDeviceChangedLegacy", (trace) async {
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
  onSelectedFiltersChanged(List<FilterSelection> selected) {
    print("updating filters legacy, selected: ${selected.length}");

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

  enableFilter(String filterName) async {
    _debounceSwitch.run(() async {
      print("enabling filter $filterName");

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
        final config = await _controller.getConfig(_selectedFilters.now);
        await traceAs("enableFilterLegacy", (trace) async {
          trace.addAttribute("lists", config.lists);
          _userConfig.now = config;
          // v2 api will be updated by the callback below
        });
      } catch (e) {
        _selectedFilters.now = was;
      }
    });
  }

  disableFilter(String filterName) async {
    _debounceSwitch.run(() async {
      print("disabling filter $filterName");

      final was = _selectedFilters.now;
      final selected = was.toList();
      selected.removeWhere((it) => it.filterName == filterName);
      _selectedFilters.now = selected;

      try {
        final config = await _controller.getConfig(_selectedFilters.now);
        await traceAs("disableFilterLegacy", (trace) async {
          trace.addAttribute("lists", config.lists);
          _userConfig.now = config;
          // v2 api will be updated by the callback below
        });
      } catch (e) {
        _selectedFilters.now = was;
      }
    });
  }

  toggleFilterOption(String filterName, String option) async {
    _debounce.run(() async {
      print("toggling filter $filterName option $option");

      final known = _knownFilters
          .get()
          .firstOrNullWhere((it) => it.filterName == filterName);
      if (known == null) {
        print("filter $filterName not found");
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
        final config = await _controller.getConfig(_selectedFilters.now);
        await traceAs("toggleFilterOptionLegacy", (trace) async {
          trace.addAttribute("lists", config.lists);
          _userConfig.now = config;
          // v2 api will be updated by the callback below
        });
      } catch (e) {
        _selectedFilters.now = was;
      }
    });
  }

  onUserConfigChanged(UserFilterConfig? config) {
    if (config == null) return;
    final lists = config.lists;
    if (lists == _device.lists?.toSet()) return;

    // UserConfigs got updated by FilterController, push to v2 api
    traceAs("onUserConfigChangedLegacy", (trace) async {
      await _device.setLists(trace, lists.toList());
    });
  }
}
