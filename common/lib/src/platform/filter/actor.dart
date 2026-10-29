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
  late final _mainPick = Core.get<BlocklistMainPick>();

  late final _toast = Core.get<ToastActor>();

  // Several quick toggles go to the server as one save.
  final Debounce _debounce;

  // The selection from before the user's first change that is not saved yet,
  // or null when no user change is pending. Saves of the defaults or a device
  // refresh leave it null, so only a save the user asked for is rolled back.
  List<FilterSelection>? _unsaved;

  // The v6 main pick from before the pending user change, when that change
  // moved it; restored with the selection if the save fails. Null: unchanged.
  ({String? tag})? _unsavedPick;

  // Counts saves started, so a save that fails after a newer one started
  // leaves the rollback to that newer save.
  int _saveCount = 0;

  // What the newest save in flight is sending. Until it lands, a change back
  // to what the device had is still a change to send.
  ({Set<String>? lists, bool safeSearch})? _sending;

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
      // A user change made while a save was in flight is not on the device
      // yet; showing the device now would undo it.
      if (lists != null && _unsaved == null) {
        await _acc.start(m); // TODO: remove this
        // Read user config from device v2 when it is ready
        // Set it and it will reload FilterController
        // That one will update SelectedFilters
        await _userConfig.change(m, _deviceConfig(lists));
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

  /// Flips one option, for the platform `toggleListByTag` command. The v6
  /// screen uses [selectMainBlocklist] and [toggleExtraBlocklist] instead.
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
      await _applyUserChange(was, m);
    });
  }

  /// Makes [key] the main blocklist of the v6 screen: every other general
  /// list goes off and [key] comes on, sent as one save. Extras stay as they
  /// are. General lists don't stack: for more blocking, pick a bigger one.
  Future<void> selectMainBlocklist(BlocklistKey key, Marker m) async {
    return await log(m).trace("selectMainBlocklist", (m) async {
      if (!v6MainBlocklists.contains(key)) {
        log(m).w("not a main blocklist: $key");
        return;
      }

      final was = await _selectedFilters.now();
      final pick = BlocklistKey.fromTag(await _mainPick.fetch(m));
      final on = selectedBlocklists(was);
      final others =
          v6MainBlocklists.where((it) => it != key && on.contains(it));
      // Already the only general list on.
      if (on.contains(key) && others.isEmpty) return;

      var selected = was;
      for (final other in others) {
        selected = withBlocklist(selected, other, false);
      }
      selected = withBlocklist(selected, key, true);

      // Saved first, so the selection change below already shows [key] as main.
      await _mainPick.change(m, key.tag);
      await _selectedFilters.change(m, selected);
      if (!await _applyUserChange(was, m, pickWas: (tag: pick?.tag))) {
        await _mainPick.change(m, pick?.tag);
      }
    });
  }

  /// Turns an extra on or off on the v6 screen. Refuses general lists, which
  /// only change through [selectMainBlocklist], and turning off the last list
  /// that is on: v6 has no "no blocklists" state, and an empty list would
  /// make FilterActor quietly put the defaults back. Safe Search is an extra
  /// here but not a list that keeps the selection from being empty.
  Future<void> toggleExtraBlocklist(BlocklistKey key, bool on, Marker m) async {
    return await log(m).trace("toggleExtraBlocklist", (m) async {
      if (v6MainBlocklists.contains(key)) {
        log(m).w("not an extra blocklist: $key");
        return;
      }
      final was = await _selectedFilters.now();
      final selected = withBlocklist(was, key, on);
      if (v6ListsOn(selected).isEmpty) {
        log(m).w("refusing to turn off the last blocklist: $key");
        return;
      }
      await _selectedFilters.change(m, selected);
      await _applyUserChange(was, m);
    });
  }

  /// Sends the selection the user just changed from [was]. Only the config
  /// changes here; the debounced [_save] sends it and confirms or rolls it
  /// back. If building the config fails, the selection goes back to [was]
  /// and this returns false.
  Future<bool> _applyUserChange(List<FilterSelection> was, Marker m,
      {({String? tag})? pickWas}) async {
    // Whether this change started the pending user change, to undo if it fails.
    var started = false;
    try {
      final config =
          await _controller.getConfig(await _selectedFilters.now(), m);
      await log(m).trace("toggleFilterOptionLegacy", (m) async {
        log(m).pair("lists", config.lists);
        // An unchanged config sends nothing, so there is nothing to confirm.
        if (_unsaved == null && config != _userConfig.present) {
          _unsaved = was;
          started = true;
        }
        // The pick from before the first change in this save, so a failed
        // save puts back the main list it showed.
        if (_unsaved != null && pickWas != null) _unsavedPick ??= pickWas;
        await _userConfig.change(m, config);
        // v2 api will be updated by the callback below, which confirms the save
      });
      return true;
    } catch (e, s) {
      log(m).e(msg: "Error toggling filter option", err: e, stack: s);
      if (started) {
        _unsaved = null;
        _unsavedPick = null;
      }
      _toast.showError("toast save failed".i18n);
      await _selectedFilters.change(m, was);
      return false;
    }
  }

  /// Pushes the selection to the v2 device. The lists and the safe search
  /// flag go together, so turning Safe Search on or off is one save and the
  /// server never has one half of it.
  onUserConfigChanged(UserFilterConfig? config) {
    if (config == null) return;
    final lists = config.lists;
    final safeSearch = config.configs[FilterConfigKey.safeSearch] ?? false;
    final saved = _sending ??
        (lists: _device.lists?.toSet(), safeSearch: _device.safeSearch ?? false);
    if (setEquals(lists, saved.lists) && safeSearch == saved.safeSearch) {
      // Back to what the device has, so an earlier toggle must not be sent.
      _debounce.cancel();
      _unsaved = null;
      _unsavedPick = null;
      return;
    }
    if (lists.isEmpty) return; // Skip setting empty list, not supported by v2
    // v2 will force the default config on empty list.
    // Instead we assume FilterController will set the defaults shortly after.

    // UserConfigs got updated by FilterController, push to v2 api
    _debounce.run(() => _save(lists.toList(), safeSearch, Markers.filter));
  }

  /// Pushes [lists] and [safeSearch] to the v2 device, the only place v6
  /// keeps them.
  /// A saved change needs no confirmation: the switches already show it. If
  /// a user change failed, an error toast shows and the switches go back to
  /// what is saved.
  Future<void> _save(List<String> lists, bool safeSearch, Marker m) async {
    final save = ++_saveCount;
    final before = _unsaved;
    final pickBefore = _unsavedPick;
    _unsaved = null;
    _unsavedPick = null;
    _sending = (lists: lists.toSet(), safeSearch: safeSearch);
    try {
      await _device.setLists(lists, m, safeSearch: safeSearch);
      if (save == _saveCount) _sending = null;
    } catch (e, s) {
      if (save == _saveCount) _sending = null;
      log(m).e(msg: "Error saving blocklists", err: e, stack: s);
      // Only a user change is rolled back: rolling back the defaults would
      // apply and retry them in a loop.
      if (before == null) return;
      _toast.showError("toast save failed".i18n);
      // A toggle made while this save was in flight is pending or already
      // saved with the full selection; rolling back now would undo it.
      if (_unsaved != null || save != _saveCount) return;
      try {
        await _restoreSaved(before, m);
        if (pickBefore != null) await _mainPick.change(m, pickBefore.tag);
      } catch (e, s) {
        // Runs from a timer, so nobody else would see this error.
        log(m).e(msg: "Error restoring saved blocklists", err: e, stack: s);
      }
    }
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
    await _userConfig.change(m, _deviceConfig(saved));
  }

  /// The config the device has. Only an enabled flag goes in, the same shape
  /// FilterActor builds, so a device with Safe Search off does not read as a
  /// change and get saved again.
  UserFilterConfig _deviceConfig(List<String> lists) => UserFilterConfig(lists.toSet(), {
        if (_device.safeSearch == true) FilterConfigKey.safeSearch: true,
      });
}
