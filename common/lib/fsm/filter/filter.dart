import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:vistraced/annotations.dart';

import '../../common/model.dart';
import '../../common/model/filter/filter_json.dart';
import '../machine.dart';

part 'filter.g.dart';

/// Filter is the latest model for handling user configurations (blocklists and
/// other blocking settings). It replaces models Pack, Deck, Shield.

typedef ListTag = String;
typedef FilterName = String;
typedef OptionName = String;
typedef ListHashId = String;
typedef Enable = bool;
typedef UserLists = Set<ListHashId>;

@context
mixin FilterContext on Context<FilterContext> {
  List<JsonListItem> lists = [];
  Map<ListHashId, ListTag> listsToTags = {};

  List<Filter> filters = [];
  List<FilterSelection> selectedFilters = [];

  Set<ListHashId>? _selectedLists;
  Map<FilterConfigKey, bool>? _configs;
  bool _defaultsApplied = false;

  // @action
  late Action<void, List<JsonListItem>> _actionLists;
  late Action<void, List<Filter>> _actionKnownFilters;
  late Action<void, List<FilterSelection>> _actionDefaultEnabled;
  late Action<UserLists, void> _actionPutUserLists;
  late Action<Map<FilterConfigKey, bool>, void> _actionPutConfig;
}

@States(FilterContext)
mixin FilterStates {
  @fatalState
  static fatal(FilterContext c) async {}

  @initialState
  static reload(FilterContext c) async {
    //whenFail(init); // todo cooldown
    c.lists = await c._actionLists(null);

    // Prepare a map for quick lookups
    c.listsToTags = {};
    for (final list in c.lists) {
      c.listsToTags[list.id] = "${list.vendor}/${list.variant}";
    }

    c._selectedLists = null;
    c._configs = null;
    c._defaultsApplied = false;

    return waitForConfig;
  }

  static waitForConfig(FilterContext c) async {
    if (c._configs != null && c._selectedLists != null) return parse;
  }

  static onConfig(
    FilterContext c,
    Set<ListHashId>? selectedLists,
    Map<FilterConfigKey, bool>? configs,
  ) async {
    c.guard([waitForConfig]);
    c._selectedLists = selectedLists;
    c._configs = configs;
    return waitForConfig;
  }

  static clearConfig(FilterContext c) async {
    c.guard([ready]);
    c._selectedLists = null;
    c._configs = null;
    return waitForConfig;
  }

  static parse(FilterContext c) async {
    // 1: read filters that we know about (no selections yet)
    c.filters = await c._actionKnownFilters(null);
    c.selectedFilters = [];

    // 2: map user selected lists to internal tags
    // Tags are "vendor/variant", like "oisd/small"
    List<ListTag> selection = [];
    for (final selectedHashId in c._selectedLists ?? {}) {
      final tag = c.listsToTags[selectedHashId];
      if (tag == null) {
        c.log("User has unknown list: $selectedHashId");
        continue;
      }

      selection += [tag];
    }

    // 3: find which filters are active based on the tags
    for (final filter in c.filters) {
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
          if (c._configs![key]!) {
            active += [option.optionName];
          }
        }
      }

      c.selectedFilters += [FilterSelection(filter.filterName, active)];
    }

    return reconfigure;
  }

  static reconfigure(FilterContext c) async {
    // 1. figure out how to activate each filter
    Set<ListHashId> lists = {};
    Map<FilterConfigKey, bool> configs = {};

    for (final selection in c.selectedFilters) {
      final filter = c.filters.firstWhere(
        (it) => it.filterName == selection.filterName,
      );

      // For each filter option, perform the action depending on its type
      for (final o in selection.options) {
        final option = filter.options.firstWhere(
          (it) => it.optionName == o,
        );

        if (option.action == FilterAction.list) {
          // For list action, activate all lists specified by the option

          // Each tag needs to be mapped to ListHashId
          for (final listTag in option.actionParams) {
            final list = c.lists.firstWhereOrNull(
              (it) => "${it.vendor}/${it.variant}" == listTag,
            );

            if (list == null) {
              // c.log("Deprecated list, ignoring: $listTag");
              continue;
            }

            lists.add(list.id);
          }
        } else if (option.action == FilterAction.config) {
          // For config action, set the config to the value specified by the option
          final key = FilterConfigKey.values.byName(option.actionParams.first);
          configs[key] = true;
        }
      }
    }

    // 2. perform the necessary activations
    bool needsReload = false;

    // List can be empty, that's ok
    if (!setEquals(lists, c._selectedLists)) {
      await c._actionPutUserLists(lists);
      needsReload = true;
    } else if (!mapEquals(configs, c._configs)) {
      await c._actionPutConfig(configs);
      needsReload = true;
    }

    if (needsReload) {
      //return waitForConfig;
    }

    return defaults;
  }

  static defaults(FilterContext c) async {
    // Do nothing if has selections
    if (c.selectedFilters.any((it) => it.options.isNotEmpty)) return ready;

    // Or if already applied during this runtime
    if (c._defaultsApplied) return ready;

    c.log("Applying defaults");
    c.selectedFilters = await c._actionDefaultEnabled(null);
    c._defaultsApplied = true;
    return reconfigure;
  }

  static ready(FilterContext c) async {}

  static onEnableFilter(
      FilterContext c, FilterName filterToChange, bool enable) async {
    c.guard([ready]);
    c.whenFail(ready);

    final filter = c.filters.firstWhere(
      (it) => it.filterName == filterToChange,
    );

    var option = [filter.options.first.optionName];
    if (!enable) option = [];

    c.selectedFilters.removeWhere((it) => it.filterName == filterToChange);
    c.selectedFilters += [FilterSelection(filterToChange, option)];

    return reconfigure;
  }

  static onToggleFilterOption(FilterContext c, FilterName filterToChange,
      OptionName optionToChange) async {
    c.guard([ready]);
    c.whenFail(ready);

    final filter = c.filters.firstWhere(
      (it) => it.filterName == filterToChange,
    );

    // Will throw if unknown option
    filter.options.firstWhere((it) => it.optionName == optionToChange);

    // Get the current option selection for this filter
    var selection = c.selectedFilters.firstWhereOrNull(
          (it) => it.filterName == filterToChange,
        ) ??
        FilterSelection(filterToChange, []);

    // Toggle the option
    if (selection.options.contains(optionToChange)) {
      selection.options.remove(optionToChange);
    } else {
      selection.options.add(optionToChange);
    }

    // Save the change
    c.selectedFilters.remove(selection);
    c.selectedFilters += [selection];

    return reconfigure;
  }
}
