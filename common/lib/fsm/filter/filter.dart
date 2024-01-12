import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../device/device.dart';
import '../../filter/channel.pg.dart' as fops;
import '../../util/di.dart';
import '../../util/trace.dart';
import '../api/api.dart';
import '../machine.dart';
import 'json.dart';
import 'known.dart';
import 'model.dart';

part 'filter.genn.dart';

/// Filter is the latest model for handling user configurations (blocklists and
/// other blocking settings). It replaces models Pack, Deck, Shield.

typedef ListTag = String;
typedef FilterName = String;
typedef OptionName = String;
typedef ListHashId = String;
typedef Enable = bool;
typedef UserLists = Set<ListHashId>;

mixin FilterContext {
  List<JsonListItem> lists = [];
  Set<ListHashId> listSelections = {};
  Map<FilterConfigKey, bool> configs = {};
  List<Filter> filters = [];
  List<FilterSelection> filterSelections = [];
  bool defaultsApplied = false;
  bool listSelectionsSet = false;
}

// @Machine
mixin FilterStates on StateMachineActions<FilterContext> {
  late Action<ApiEndpoint> _api;
  late Action<UserLists> _putUserLists;

  // @initial
  init(FilterContext c) async {
    return fetchLists;
  }

  // @fatal
  fatal(FilterContext c) async {}

  fetchLists(FilterContext c) async {
    _api(ApiEndpoint.getList);

    // TODO: configs
    c.configs = {};

    return waiting;
  }

  waiting(FilterContext c) async {
    if (c.listSelectionsSet && c.lists.isNotEmpty /*&& c.configs.isNotEmpty*/) {
      return parse;
    }
  }

  onApiOk(FilterContext c, String result) async {
    guard(waiting);
    c.lists = JsonListEndpoint.fromJson(jsonDecode(result)).lists;
    return waiting;
  }

  // Some retry logic?
  onApiFail(FilterContext c) async => init;

  onUserLists(FilterContext c, UserLists lists) async {
    c.listSelections = lists;
    c.listSelectionsSet = true;
    return waiting;
  }

  parse(FilterContext c) async {
    // 1: read filters that we know about (no selections yet)
    c.filters = getKnownFilters(act());
    c.filterSelections = [];

    // 2: map user selected lists to internal tags
    // Tags are "vendor/variant", like "oisd/small"
    List<ListTag> selection = [];
    for (final selectedHashId in c.listSelections) {
      final list = c.lists.firstWhereOrNull((it) => it.id == selectedHashId);
      if (list == null) {
        log("User has unknown list: $selectedHashId");
        continue;
      }

      selection += ["${list.vendor}/${list.variant}"];
    }

    // 3: find which filters are active based on the tags
    for (final filter in c.filters) {
      List<OptionName> active = [];
      for (final option in filter.options) {
        // For List actions, assume an option is active, if all lists specified
        // for this option are active
        if (option.action == FilterAction.list) {
          if (option.actionParams.every((it) => selection.contains(it))) {
            active += [option.optionName];
          }
        }
        // TODO: other options
      }

      c.filterSelections += [FilterSelection(filter.filterName, active)];
    }

    return reconfigure;
  }

  reconfigure(FilterContext c) async {
    // 1. figure out how to activate each filter
    Set<ListHashId> lists = {};
    for (final selection in c.filterSelections) {
      final filter = c.filters.firstWhere(
        (it) => it.filterName == selection.filterName,
      );

      // For each filter option, perform the action depending on its type
      for (final o in selection.options) {
        final option = filter.options.firstWhere(
          (it) => it.optionName == o,
        );

        // For list action, activate all lists specified by the option
        if (option.action == FilterAction.list) {
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
        }
        // TODO: other actions
      }
    }

    // 2. perform the necessary activations
    bool needsReload = false;

    // For now it's only about lists
    // List can be empty, that's ok
    if (!setEquals(lists, c.listSelections)) {
      needsReload = true;
      await _putUserLists(lists);
    }

    // TODO: other actions

    if (needsReload) {
      // Risk of loop if api misbehaves
      //setState(FilterState.load);
    }

    return defaults;
  }

  defaults(FilterContext c) async {
    // Do nothing if has selections
    if (c.filterSelections.any((it) => it.options.isNotEmpty)) return ready;

    // Or if already applied during this runtime
    if (c.defaultsApplied) return ready;

    log("Applying defaults");
    c.filterSelections = getDefaultEnabled(act());
    c.defaultsApplied = true;
    return reconfigure;
  }

  ready(FilterContext c) async {}

  onEnableFilter(FilterContext c, String filterName, bool enable) async {
    guard(ready);
    whenFail(ready);

    final filter = c.filters.firstWhere(
      (it) => it.filterName == filterName,
    );

    var option = [filter.options.first.optionName];
    if (!enable) option = [];

    c.filterSelections.removeWhere((it) => it.filterName == filterName);
    c.filterSelections += [FilterSelection(filterName, option)];

    return reconfigure;
  }

  onToggleFilterOption(
      FilterContext c, String filterName, String optionName) async {
    guard(ready);
    whenFail(ready);

    final filter = c.filters.firstWhere(
      (it) => it.filterName == filterName,
    );

    // Will throw if unknown option
    filter.options.firstWhere((it) => it.optionName == optionName);

    // Get the current option selection for this filter
    var selection = c.filterSelections.firstWhereOrNull(
          (it) => it.filterName == filterName,
        ) ??
        FilterSelection(filterName, []);

    // Toggle the option
    if (selection.options.contains(optionName)) {
      selection.options.remove(optionName);
    } else {
      selection.options.add(optionName);
    }

    // Save the change
    c.filterSelections.remove(selection);
    c.filterSelections += [selection];

    return reconfigure;
  }

  onReload(FilterContext c) async {
    guard(ready);
    return fetchLists;
  }
}

class FilterActor extends _$FilterActor with TraceOrigin {
  FilterActor(Act act) : super(act) {
    if (!act.isProd()) return;

    injectApi((it) async {
      final actor = ApiActor(act);
      actor.whenState("ready", (c) async {
        try {
          await actor.apiRequest(it);
          final result = await actor.waitForState("success");
          apiOk(result.result!);
        } catch (e) {
          apiFail(e as Exception);
        }
      });
    });

    final device = dep<DeviceStore>();
    device.addOn(deviceChanged, (trace) {
      userLists(device.lists?.toSet() ?? {});
    });

    injectPutUserLists((it) async {
      await traceAs("setLists", (trace) async {
        await device.setLists(trace, it.toList());
      });
    });

    final ops = fops.FilterOps();

    addOnState("ready", "ops", (state, context) {
      final filters = context.filters
          .map((it) => fops.Filter(
                filterName: it.filterName,
                options: it.options.map((it) => it.optionName).toList(),
              ))
          .toList();
      ops.doFiltersChanged(filters);

      final selections = context.filterSelections
          .map((it) => fops.Filter(
                filterName: it.filterName,
                options: it.options,
              ))
          .toList();
      ops.doFilterSelectionChanged(selections);
    });
  }
}
