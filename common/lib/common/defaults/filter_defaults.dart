import '../../util/di.dart';
import '../model.dart';

List<FilterSelection> getDefaultEnabled(Act act) {
  if (act.isFamily()) return _familyEnabled;
  return _v6Enabled;
}

final _v6Enabled = [
  FilterSelection("oisd", ["small"]),
];

final _familyEnabled = [
  FilterSelection("meta_safe_search", ["safe search"]),
  FilterSelection("meta_ads", ["standard"]),
];
