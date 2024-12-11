part of 'filter.dart';

class FilterActor with Logging, Actor {
  late final _apiLists = Core.get<ListApi>();
  late final _knownFilters = Core.get<KnownFilters>();
  late final _defaultFilters = Core.get<DefaultFilters>();
  late final _selectedFilters = Core.get<SelectedFilters>();
  late final _userConfig = Core.get<CurrentConfig>();

  var _listsToTags = <ListHashId, ListTag>{};
  DateTime lastListsFetch = DateTime(0);

  bool _defaultsApplied = false;
  bool _needsReload = true;

  List<JsonListItem> _lists = [];

  FilterActor() {
    _userConfig.onChange.listen((_) => reload(Markers.filter));
    _selectedFilters.change(Markers.filter, []);
  }

  maybeGetLists(Marker m) async {
    if (_lists.isEmpty || _needsReload) {
      _lists = await _apiLists.get(m);
      _needsReload = false;
    }
  }

  Map<ListHashId, ListTag> getListsToTags() => _listsToTags;

  reload(Marker m) async {
    return await log(m).trace("reload", (m) async {
      log(m).i("reloading filter controller");
      await maybeGetLists(m);

      // Prepare a map for quick lookups
      _listsToTags = {};
      for (final list in _lists) {
        _listsToTags[list.id] = "${list.vendor}/${list.variant}";
      }

//    _configs = null;
      _defaultsApplied = false;

      await _parse(m);
    });
  }

  String getFilterContainingList(ListHashId id, {bool full = false}) {
    log(Markers.root).t("getFilterContainingList: $id");

    final list = _lists.firstWhereOrNull((it) => it.id == id);
    if (list == null) {
      if (id.isBlank) return "family stats label none".i18n;
      if (id.length < 16) return "family stats title".i18n; // My exceptions
      return "family stats label none".i18n;
    }

    String? filterName;
    String? optionName;

    outer:
    for (var filter in _knownFilters.get()) {
      for (var option in filter.options) {
        if (option.action == FilterAction.list &&
            option.actionParams.contains("${list.vendor}/${list.variant}")) {
          filterName = filter.filterName;
          optionName = option.optionName;
          break outer;
        }

        // Repeat same thing for the optional second action
        if (option.action2 == FilterAction.list &&
            option.action2Params!.contains("${list.vendor}/${list.variant}")) {
          filterName = filter.filterName;
          optionName = option.optionName;
          break outer;
        }
      }
    }

    filterName = filterDecorDefaults
        .firstWhereOrNull((it) => it.filterName == filterName)
        ?.title;

    if (filterName == null) return "family stats label none".i18n;

    if (full && optionName != null) {
      return "$filterName (${optionName.firstLetterUppercase()})";
    }

    return filterName;
  }

  Future<UserFilterConfig> getConfig(List<FilterSelection> s, Marker m) async {
    final filters = _knownFilters.get();
    await maybeGetLists(m);

    Set<ListHashId> shouldBeLists = {};
    Map<FilterConfigKey, bool> shouldBeConfigs = {};

    for (final selection in s) {
      final filter =
          filters.firstWhere((it) => it.filterName == selection.filterName);

      for (final o in selection.options) {
        final option = filter.options.firstWhere(
          (it) => it.optionName == o,
        );
        log(m).i("getConfig: for option ${option.optionName}");

        if (option.action == FilterAction.list) {
          for (final listTag in option.actionParams) {
            final list = _lists.firstWhereOrNull(
              (it) => "${it.vendor}/${it.variant}" == listTag,
            );

            if (list == null) {
              // c.log("Deprecated list, ignoring: $listTag");
              continue;
            }

            shouldBeLists.add(list.id);
          }
        } else if (option.action == FilterAction.config) {
          final key = FilterConfigKey.values.byName(option.actionParams.first);
          shouldBeConfigs[key] = true;
        }

        // Repeat same thing for the optional second action
        if (option.action2 == FilterAction.list) {
          for (final listTag in option.action2Params!) {
            final list = _lists.firstWhereOrNull(
              (it) => "${it.vendor}/${it.variant}" == listTag,
            );

            if (list == null) {
              // c.log("Deprecated list, ignoring: $listTag");
              continue;
            }

            shouldBeLists.add(list.id);
          }
        } else if (option.action2 == FilterAction.config) {
          final key =
              FilterConfigKey.values.byName(option.action2Params!.first);
          shouldBeConfigs[key] = true;
        }
      }
    }

    log(m).i("getConfig, configs: $shouldBeConfigs");
    return UserFilterConfig(shouldBeLists, shouldBeConfigs);
  }

  _parse(Marker m) async {
    // 1: read filters that we know about (no selections yet)
    final filters = _knownFilters.get();
    final userConfig = (await _userConfig.now())!;
    final selectedFilters = <FilterSelection>[];

    // 2: map user selected lists to internal tags
    // Tags are "vendor/variant", like "oisd/small"
    List<ListTag> selection = [];
    for (final selectedHashId in userConfig.lists) {
      final tag = _listsToTags[selectedHashId];
      if (tag == null) {
        //c.log("User has unknown list: $selectedHashId");
        continue;
      }

      selection += [tag];
    }

    // 3: find which filters are active based on the tags
    for (final filter in filters) {
      List<OptionName> active = [];
      for (final option in filter.options) {
        if (option.action == FilterAction.list) {
          // For List actions, assume an option is active, if all lists specified
          // for this option are active
          if (option.actionParams.every((it) => selection.contains(it))) {
            active += [option.optionName];
          }
        } else if (option.action == FilterAction.config) {
          // For Config actions, assume an option is active, if the config is set
          final key = FilterConfigKey.values.byName(option.actionParams.first);
          if (userConfig.configs[key] == true) {
            active += [option.optionName];
          }
        }

        // Repeat same thing for the optional second action
        if (option.action2 == FilterAction.list) {
          // For List actions, assume an option is active, if all lists specified
          // for this option are active
          if (option.action2Params!.every((it) => selection.contains(it))) {
            active += [option.optionName];
          }
        } else if (option.action2 == FilterAction.config) {
          // For Config actions, assume an option is active, if the config is set
          final key =
              FilterConfigKey.values.byName(option.action2Params!.first);
          if (userConfig.configs[key] == true) {
            active += [option.optionName];
          }
        }
      }

      selectedFilters
          .add(FilterSelection(filter.filterName, active.distinct().toList()));
    }

    await _selectedFilters.change(m, selectedFilters);
    _reconfigure(m);
  }

  _reconfigure(Marker m) async {
    final filters = _knownFilters.get();
    final selectedFilters = await _selectedFilters.now();
    final userConfig = _userConfig.present;

    // 1. figure out how to activate each filter
    Set<ListHashId> shouldBeLists = {};
    Map<FilterConfigKey, bool> shouldBeConfigs = {};

    for (final selection in selectedFilters) {
      final filter =
          filters.firstWhere((it) => it.filterName == selection.filterName);

      // For each filter option, perform the action depending on its type
      for (final o in selection.options) {
        final option = filter.options.firstWhere(
          (it) => it.optionName == o,
        );

        if (option.action == FilterAction.list) {
          // For list action, activate all lists specified by the option

          // Each tag needs to be mapped to ListHashId
          for (final listTag in option.actionParams) {
            final list = _lists.firstWhereOrNull(
              (it) => "${it.vendor}/${it.variant}" == listTag,
            );

            if (list == null) {
              // c.log("Deprecated list, ignoring: $listTag");
              continue;
            }

            shouldBeLists.add(list.id);
          }
        } else if (option.action == FilterAction.config) {
          // For config action, set the config to the value specified by the option
          final key = FilterConfigKey.values.byName(option.actionParams.first);
          shouldBeConfigs[key] = true;
        }

        // Repeat same thing for the optional second action
        if (option.action2 == FilterAction.list) {
          // For list action, activate all lists specified by the option

          // Each tag needs to be mapped to ListHashId
          for (final listTag in option.action2Params!) {
            final list = _lists.firstWhereOrNull(
              (it) => "${it.vendor}/${it.variant}" == listTag,
            );

            if (list == null) {
              // c.log("Deprecated list, ignoring: $listTag");
              continue;
            }

            shouldBeLists.add(list.id);
          }
        } else if (option.action2 == FilterAction.config) {
          // For config action, set the config to the value specified by the option
          final key =
              FilterConfigKey.values.byName(option.action2Params!.first);
          shouldBeConfigs[key] = true;
        }
      }
    }

    // 2. perform the necessary activations
    // List can be empty, that's ok
    final shouldBeConfig = UserFilterConfig(shouldBeLists, shouldBeConfigs);
    if (userConfig != shouldBeConfig) {
      log(m).i("reloading based on userconfig");
      await _userConfig.change(m, shouldBeConfig);
      _needsReload = true;
      return;
    }

    await _defaults(m);
  }

  _defaults(Marker m) async {
    final selectedFilters = await _selectedFilters.now();

    // Do nothing if has selections
    if (selectedFilters.any((it) => it.options.isNotEmpty)) return;

    // Or if already applied during this runtime
    if (_defaultsApplied) return;

    if (!Core.act.isFamily) {
      log(m).i("Applying defaults");
      final defaults = _defaultFilters.get();
      await _selectedFilters.change(m, defaults);
    }

    _defaultsApplied = true;
    await _reconfigure(m);
  }
}
