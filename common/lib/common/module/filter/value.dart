part of 'filter.dart';

class CurrentConfig extends NullableAsyncValue<UserFilterConfig> {}

class SelectedFilters extends AsyncValue<List<FilterSelection>> {
  SelectedFilters() {
    load = (Marker m) async => <FilterSelection>[];
  }
}
