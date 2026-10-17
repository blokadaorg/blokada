part of 'filter.dart';

// This is a legacy layer that brings the new Filter concept
// to the existing platform code that used Decks/Packs.

// Initially, the app was hybrid with the business logic in Flutter,
// and UI made separately for each platform in SwiftUI / Kotlin.
// Now, we are moving to UI being made fully in Flutter.

// However, we wanted the new Filters faster since the old concept
// was problematic and buggy. So this class exposes it to for old code.
class PlatformFilterActor with Logging, Actor {
  late final _controller = Core.get<FilterActor>();
  late final _device = Core.get<DeviceStore>();
  late final _userConfig = Core.get<CurrentConfig>();
  late final _selectedFilters = Core.get<SelectedFilters>();
  late final _knownFilters = Core.get<KnownFilters>();
  late final _acc = Core.get<AccountActor>();

  late final _toast = Core.get<ToastActor>();

  // Several quick toggles go to the server as one save.
  final Debounce _debounce;

  // The selection from before the user's first change that is not saved yet,
  // or null when no user change is pending. Saves of the defaults or a device
  // refresh leave it null, so only a save the user asked for gets a toast.
  List<FilterSelection>? _unsaved;

  PlatformFilterActor({Duration debounce = const Duration(seconds: 1)})
      : _debounce = Debounce(debounce);

  @override
  onStart(Marker m) async {
    _device.addOn(deviceChanged, onDeviceChanged);
    _userConfig.onChange.listen((it) => onUserConfigChanged(it.now));
    // todo: default value at first start of new account
  }

  Future<void> onDeviceChanged(Marker m) async {
    return await log(m).trace("onDeviceChangedLegacy", (m) async {
      final lists = _device.lists;
      if (lists != null) {
        await _acc.start(m); // TODO: remove this
        // Read user config from device v2 when it is ready
        // Set it and it will reload FilterController
        // That one will update SelectedFilters
        await _userConfig.change(m, UserFilterConfig(lists.toSet(), {}));
      }
    });
  }

  enableFilter(String filterName, Marker m) async {
    log(m).i("enabling filter $filterName");

    final known = _knownFilters
        .get()
        .firstOrNullWhere((it) => it.filterName == filterName);
    final newFilter =
        FilterSelection(filterName, [known!.options.first.optionName]);

    final was = await _selectedFilters.now();
    final selected = was.toList();
    final index = selected.indexWhere((it) => it.filterName == filterName);
    if (index != -1) {
      selected[index] = newFilter;
    } else {
      selected.add(newFilter);
    }
    await _selectedFilters.change(m, selected);

    try {
      final config =
          await _controller.getConfig(await _selectedFilters.now(), m);
      await log(m).trace("enableFilterLegacy", (m) async {
        log(m).pair("lists", config.lists);
        await _userConfig.change(m, config);
        // v2 api will be updated by the callback below
      });
    } catch (e) {
      await _selectedFilters.change(m, was);
    }
  }

  disableFilter(String filterName, Marker m) async {
    log(m).i("disabling filter $filterName");

    final was = await _selectedFilters.now();
    final selected = was.toList();
    selected.removeWhere((it) => it.filterName == filterName);
    await _selectedFilters.change(m, selected);

    try {
      final config =
          await _controller.getConfig(await _selectedFilters.now(), m);
      await log(m).trace("disableFilterLegacy", (m) async {
        log(m).pair("lists", config.lists);
        await _userConfig.change(m, config);
        // v2 api will be updated by the callback below
      });
    } catch (e) {
      await _selectedFilters.change(m, was);
    }
  }

  /// Flips one option from the blocklists screen. Only the selection changes
  /// here; the debounced [_save] sends it and confirms or rolls it back.
  toggleFilterOption(String filterName, String option, Marker m) async {
    return await log(m).trace("toggleFilterOption", (m) async {
      final known = _knownFilters
          .get()
          .firstOrNullWhere((it) => it.filterName == filterName);
      if (known == null) {
        log(m).i("filter $filterName not found");
        return;
      }

      final newFilter = FilterSelection(filterName, [option]);

      final was = await _selectedFilters.now();
      // Copy to ensure another object
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
      await _selectedFilters.change(m, selected);

      try {
        final config =
            await _controller.getConfig(await _selectedFilters.now(), m);
        await log(m).trace("toggleFilterOptionLegacy", (m) async {
          log(m).pair("lists", config.lists);
          _unsaved ??= was;
          await _userConfig.change(m, config);
          // v2 api will be updated by the callback below, which confirms the save
        });
      } catch (e, s) {
        log(m).e(msg: "Error toggling filter option", err: e, stack: s);
        _toast.showError("toast save failed".i18n);
        await _selectedFilters.change(m, was);
      }
    });
  }

  onUserConfigChanged(UserFilterConfig? config) {
    if (config == null) return;
    final lists = config.lists;
    if (setEquals(lists, _device.lists?.toSet())) {
      // Back to what the device has, so an earlier toggle must not be sent.
      _debounce.cancel();
      _unsaved = null;
      return;
    }
    if (lists.isEmpty) return; // Skip setting empty list, not supported by v2
    // v2 will force the default config on empty list.
    // Instead we assume FilterController will set the defaults shortly after.

    // UserConfigs got updated by FilterController, push to v2 api
    _debounce.run(() => _save(lists.toList(), Markers.filter));
  }

  /// Pushes [lists] to the v2 device, the only place blocklists are saved.
  /// A user change is confirmed once the server took it. If the save failed,
  /// an error toast replaces the confirmation and the switches go back to
  /// what is saved.
  Future<void> _save(List<String> lists, Marker m) async {
    final before = _unsaved;
    _unsaved = null;
    final bool saved;
    try {
      saved = await _device.setLists(lists, m);
    } catch (e, s) {
      log(m).e(msg: "Error saving blocklists", err: e, stack: s);
      // Only a user change is rolled back: rolling back the defaults would
      // apply and retry them in a loop.
      if (before == null) return;
      _toast.showError("toast save failed".i18n);
      await _restoreSaved(before, m);
      return;
    }
    if (saved && before != null) _toast.show("toast blocklists saved".i18n);
  }

  // The device lists are what the server has; FilterActor maps them back to
  // switches. Before the first device fetch there are none, so the selection
  // from before the change stands in.
  Future<void> _restoreSaved(List<FilterSelection> before, Marker m) async {
    final saved = _device.lists;
    if (saved == null) {
      await _selectedFilters.change(m, before);
      return;
    }
    await _userConfig.change(m, UserFilterConfig(saved.toSet(), {}));
  }
}
