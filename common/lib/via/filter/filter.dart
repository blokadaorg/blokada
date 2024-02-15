import 'package:common/via/util.dart';
import 'package:flutter/foundation.dart';
import 'package:vistraced/via.dart';

import '../../common/model.dart';
import '../../common/model/filter/filter_json.dart';
import '../actions.dart';

part 'filter.g.dart';

@Module([SimpleMatcher(FilterMachine)])
class FilterModule extends _$FilterModule {}

@Injected()
class FilterMachine {
  @MatcherSpec(of: ofApi)
  final _lists = Via.as<List<JsonListItem>>();

  @MatcherSpec(of: ofGenerator)
  final _filters = Via.as<List<Filter>>() /*..also(doPlatform)*/;

  @MatcherSpec(of: ofPlatform)
  final _selectedFilters = Via.as<List<FilterSelection>>();

  @MatcherSpec(of: ofDirect)
  final _userConfig = Via.as<UserFilterConfig?>();

  @MatcherSpec(of: ofDefaults)
  final _defaultFilters = Via.as<List<FilterSelection>>();

  var _listsToTags = <ListHashId, ListTag>{};

  bool _defaultsApplied = false;
  bool _needsReload = true;

  FilterMachine() {
    _userConfig.also(reload);
  }

  reload() async {
    final lists = await _lists.fetch();

    // Prepare a map for quick lookups
    _listsToTags = {};
    for (final list in lists) {
      _listsToTags[list.id] = "${list.vendor}/${list.variant}";
    }

//    _configs = null;
    _defaultsApplied = false;
    _needsReload = false;

    await _parse();
  }

  _parse() async {
    // 1: read filters that we know about (no selections yet)
    final filters = await _filters.fetch();
    final userConfig = await _userConfig.fetch();
    final selectedFilters = <FilterSelection>[];

    // 2: map user selected lists to internal tags
    // Tags are "vendor/variant", like "oisd/small"
    List<ListTag> selection = [];
    for (final selectedHashId in userConfig?.lists ?? {}) {
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
          if (userConfig!.configs[key]!) {
            active += [option.optionName];
          }
        }
      }

      selectedFilters.add(FilterSelection(filter.filterName, active));
    }

    _selectedFilters.set(selectedFilters);
    _reconfigure();
  }

  _reconfigure() async {
    final filters = await _filters.fetch();
    final selectedFilters = await _selectedFilters.fetch();
    final lists = await _lists.fetch();
    final userConfig = await _userConfig.fetch();

    // 1. figure out how to activate each filter
    Set<ListHashId> shouldBeLists = {};
    Map<FilterConfigKey, bool> shouldBeConfigs = {};

    for (final selection in selectedFilters) {
      final filter =
          filters.find((it) => it.filterName == selection.filterName)!;

      // For each filter option, perform the action depending on its type
      for (final o in selection.options) {
        final option = filter.options.firstWhere(
          (it) => it.optionName == o,
        );

        if (option.action == FilterAction.list) {
          // For list action, activate all lists specified by the option

          // Each tag needs to be mapped to ListHashId
          for (final listTag in option.actionParams) {
            final list = lists.find(
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
      }
    }

    // 2. perform the necessary activations
    // List can be empty, that's ok
    final shouldBeConfig = UserFilterConfig(shouldBeLists, shouldBeConfigs);
    if (userConfig != shouldBeConfig) {
      await _userConfig.set(shouldBeConfig);
      _needsReload = true;
      return;
    }

    await _defaults();
  }

  _defaults() async {
    final selectedFilters = await _selectedFilters.fetch();

    // Do nothing if has selections
    if (selectedFilters.any((it) => it.options.isNotEmpty)) return;

    // Or if already applied during this runtime
    if (_defaultsApplied) return;

    //c.log("Applying defaults");
    final defaults = await _defaultFilters.fetch();
    _selectedFilters.set(defaults);

    _defaultsApplied = true;
    await _reconfigure();
  }
}
