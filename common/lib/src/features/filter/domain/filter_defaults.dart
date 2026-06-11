part of 'filter.dart';

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
        // Empty/unknown template (e.g. the family +New profile flow passes "")
        // must fall back to the flavor's own defaults. Returning the v6 set in
        // the family app yields filter names the family `KnownFilters` don't
        // contain, which made `FilterActor.getConfig` throw and silently abort
        // profile creation.
        return isFamily ? _familyEnabled : _v6Enabled;
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
