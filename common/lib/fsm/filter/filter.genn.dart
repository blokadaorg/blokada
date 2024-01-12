part of 'filter.dart';

class _FilterContext with FilterContext, Context<_FilterContext> {
  _FilterContext(
    List<JsonListItem> lists,
    Set<ListHashId> listSelections,
    Map<FilterConfigKey, bool> configs,
    List<Filter> filters,
    List<FilterSelection> filterSelections,
    bool defaultsApplied,
    bool listSelectionsSet,
  ) {
    this.lists = lists;
    this.listSelections = listSelections;
    this.configs = configs;
    this.filters = filters;
    this.filterSelections = filterSelections;
    this.defaultsApplied = defaultsApplied;
    this.listSelectionsSet = listSelectionsSet;
  }

  _FilterContext.empty();

  @override
  Context<_FilterContext> copy() => _FilterContext(lists, listSelections,
      configs, filters, filterSelections, defaultsApplied, listSelectionsSet);

  @override
  String toString() =>
      "FilterContext{defaultsApplied: $defaultsApplied, listSelections: $listSelections, configs: $configs, filterSelections: $filterSelections}";
}

class _$FilterStates extends StateMachine<_FilterContext>
    with StateMachineActions<FilterContext>, FilterStates {
  _$FilterStates(Act act)
      : super("init", _FilterContext.empty(), FailBehavior("fatal")) {
    states = {
      init: "init",
      fetchLists: "fetchLists",
      waiting: "waiting",
      parse: "parse",
      reconfigure: "reconfigure",
      defaults: "defaults",
      ready: "ready",
      fatal: "fatal",
    };

    whenFail = (state, {saveContext = false}) =>
        failBehavior = FailBehavior(states[state]!, saveContext: saveContext);
    guard = (state) => guardState(state);
    wait = (state) => waitForState(states[state]!);
    log = (msg) => handleLog(msg);
    this.act = () => act;

    enter("init");
  }

  eventOnApiOk(String result) async {
    event("apiOk", (c) async => await onApiOk(c, result));
  }

  eventOnApiFail(Exception error) async {
    event("apiFail", (c) async => await onApiFail(c));
  }

  eventOnUserLists(UserLists lists) async {
    event("userLists", (c) async => await onUserLists(c, lists));
  }

  eventEnableFilter(String filterName, bool enable) async {
    event("enableFilter",
        (c) async => await onEnableFilter(c, filterName, enable));
  }

  eventToggleFilterOption(String filterName, String optionName) async {
    event("toggleFilterOption",
        (c) async => await onToggleFilterOption(c, filterName, optionName));
  }

  eventReload() async {
    event("reload", (c) async => await onReload(c));
  }
}

class _$FilterActor {
  late final _$FilterStates _machine;

  _$FilterActor(Act act) {
    _machine = _$FilterStates(act);
  }

  injectApi(Action<ApiEndpoint> api) {
    _machine._api = (it) async {
      _machine.log("api: $it");
      Future(() {
        // TODO: try catch
        api(it);
      });
    };
  }

  injectPutUserLists(Action<UserLists> putUserLists) {
    _machine._putUserLists = (it) async {
      _machine.log("putUserLists: $it");
      Future(() {
        putUserLists(it);
      });
    };
  }

  enableFilter(String filterName, bool enable) =>
      _machine.eventEnableFilter(filterName, enable);
  toggleFilterOption(String filterName, String optionName) =>
      _machine.eventToggleFilterOption(filterName, optionName);
  reload() => _machine.eventReload();

  apiOk(String result) => _machine.eventOnApiOk(result);
  apiFail(Exception error) => _machine.eventOnApiFail(error);
  userLists(UserLists lists) => _machine.eventOnUserLists(lists);

  waitForState(String state) => _machine.waitForState(state);
  addOnState(String state, String tag, Function(State, FilterContext) fn) =>
      _machine.addOnState(state, tag, fn);

  whenState(State state, Function(FilterContext) fn) =>
      _machine.whenState(state, fn);
}
