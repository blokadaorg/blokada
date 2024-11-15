import '../model/model.dart';

class DefaultFilters {
  final bool isFamily;

  DefaultFilters(this.isFamily);

  List<FilterSelection> get() => getTemplate(isFamily ? "family" : null);

  List<FilterSelection> getTemplate(String? template) {
    switch (template) {
      case "family":
        return _familyEnabled;
      case "parent":
        return _familyEnabled;
      case "child":
        return _childEnabled;
      default:
        return _v6Enabled;
    }
  }
}

final _v6Enabled = [
  FilterSelection("oisd", ["small"]),
];

final _familyEnabled = [
  FilterSelection(filterAds, [filterOptionPrimary]),
];

final _childEnabled = [
  FilterSelection(filterSafeSearch, [filterOptionSafeSearch]),
  FilterSelection(filterAds, [filterOptionPrimary]),
  //FilterSelection(filterAdult, [filterOptionPorn]),
];
