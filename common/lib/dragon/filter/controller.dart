import 'package:collection/collection.dart';
import 'package:common/common/defaults/filter_decor_defaults.dart';
import 'package:common/common/defaults/filter_defaults.dart';
import 'package:common/common/i18n.dart';
import 'package:dartx/dartx.dart';

import '../../common/model.dart';
import '../../util/di.dart';
import '../device/current_config.dart';
import '../list/api.dart';
import 'selected_filters.dart';

class FilterController {
  late final _apiLists = dep<ListApi>();
  late final _knownFilters = dep<KnownFilters>();
  late final _defaultFilters = dep<DefaultFilters>();
  late final _selectedFilters = dep<SelectedFilters>();
  late final _userConfig = dep<CurrentConfig>();

  var _listsToTags = <ListHashId, ListTag>{};

  bool _defaultsApplied = false;
  bool _needsReload = true;

  List<JsonListItem> _lists = [];

  FilterController() {
    _userConfig.onChange.listen((_) => reload());
    _selectedFilters.now = [];
  }

  getLists() async {
    if (_lists.isEmpty) {
      _lists = await _apiLists.get();
    }
  }

  Map<ListHashId, ListTag> getListsToTags() => _listsToTags;

  reload() async {
    print("reloading filter controller");
    await getLists();

    // Prepare a map for quick lookups
    _listsToTags = {};
    for (final list in _lists) {
      _listsToTags[list.id] = "${list.vendor}/${list.variant}";
    }

//    _configs = null;
    _defaultsApplied = false;
    _needsReload = false;

    await _parse();
  }

  String getFilterContainingList(ListHashId id) {
    final list = _lists.firstWhereOrNull((it) => it.id == id);
    if (list == null) return "family stats label none".i18n;

    String? filterName;
    outer:
    for (var filter in _knownFilters.get()) {
      for (var option in filter.options) {
        if (option.action == FilterAction.list &&
            option.actionParams.contains("${list.vendor}/${list.variant}")) {
          filterName = filter.filterName;
          break outer;
        }

        // Repeat same thing for the optional second action
        if (option.action2 == FilterAction.list &&
            option.action2Params!.contains("${list.vendor}/${list.variant}")) {
          filterName = filter.filterName;
          break outer;
        }
      }
    }

    filterName = filterDecorDefaults
        .firstWhereOrNull((it) => it.filterName == filterName)
        ?.title;

    if (filterName == null) return "family stats label none".i18n;

    return filterName;
  }

  Future<UserFilterConfig> getConfig(List<FilterSelection> s) async {
    final filters = _knownFilters.get();
    await getLists();

    Set<ListHashId> shouldBeLists = {};
    Map<FilterConfigKey, bool> shouldBeConfigs = {};

    for (final selection in s) {
      final filter =
          filters.firstWhere((it) => it.filterName == selection.filterName);

      for (final o in selection.options) {
        final option = filter.options.firstWhere(
          (it) => it.optionName == o,
        );
        print("getConfig: for option ${option.optionName}");

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

    print("getConfig, configs: ${shouldBeConfigs}");
    return UserFilterConfig(shouldBeLists, shouldBeConfigs);
  }

  _parse() async {
    // 1: read filters that we know about (no selections yet)
    final filters = await _knownFilters.get();
    final userConfig = _userConfig.now!;
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

    _selectedFilters.now = selectedFilters;
    _reconfigure();
  }

  _reconfigure() async {
    final filters = _knownFilters.get();
    final selectedFilters = _selectedFilters.now;
    final lists = await _apiLists.get();
    final userConfig = _userConfig.now;

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
            final list = lists.firstWhereOrNull(
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
            final list = lists.firstWhereOrNull(
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
      print("reloading based on userconfig");
      _userConfig.now = shouldBeConfig;
      _needsReload = true;
      return;
    }

    await _defaults();
  }

  _defaults() async {
    final selectedFilters = _selectedFilters.now;

    // Do nothing if has selections
    if (selectedFilters.any((it) => it.options.isNotEmpty)) return;

    // Or if already applied during this runtime
    if (_defaultsApplied) return;

    //c.log("Applying defaults");
    // final defaults = _defaultFilters.get();
    // _selectedFilters.now = defaults;

    _defaultsApplied = true;
    await _reconfigure();
  }
}
