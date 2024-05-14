part of '../../model.dart';

typedef FilterName = String;
typedef OptionName = String;
typedef Enable = bool;
typedef UserConfigs = Map<FilterConfigKey, bool>;

class Filter {
  final String filterName;
  final List<Option> options;

  Filter(this.filterName, this.options);
}

class FilterSelection {
  final String filterName;
  final List<String> options;

  FilterSelection(this.filterName, this.options);

  @override
  String toString() =>
      "FilterSelection{filterName: $filterName, options: $options}";
}

class Option {
  final String optionName;
  final FilterAction action;
  final List<String> actionParams;
  final FilterAction? action2;
  final List<String>? action2Params;

  Option(this.optionName, this.action, this.actionParams,
      {this.action2, this.action2Params});
}

enum FilterAction { list, config }

enum FilterConfigKey { safeSearch }

class UserFilterConfig {
  final UserLists lists;
  final UserConfigs configs;

  UserFilterConfig(this.lists, this.configs);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserFilterConfig &&
        setEquals(other.lists, lists) &&
        mapEquals(other.configs, configs);
  }

  @override
  int get hashCode => lists.hashCode ^ configs.hashCode;
}
