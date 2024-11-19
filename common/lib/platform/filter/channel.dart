part of 'filter.dart';

mixin FilterChannel {
  Future<void> doFiltersChanged(List<Filter> filters);
  Future<void> doFilterSelectionChanged(List<FilterSelection> filters);
  Future<void> doListToTagChanged(Map<String, String> listToTag);
}

class PlatformFilterChannel with FilterChannel {
  late final _platform = channel.FilterOps();

  @override
  Future<void> doFiltersChanged(List<Filter> filters) {
    final f = filters.map((it) {
      return channel.Filter(
        filterName: it.filterName,
        options: it.options.map((e) => e.optionName).toList(),
      );
    }).toList();

    return _platform.doFiltersChanged(f);
  }

  @override
  Future<void> doFilterSelectionChanged(List<FilterSelection> filters) {
    final f = filters.map((it) {
      return channel.Filter(
        filterName: it.filterName,
        options: it.options,
      );
    }).toList();

    return _platform.doFilterSelectionChanged(f);
  }

  @override
  Future<void> doListToTagChanged(Map<String, String> listToTag) =>
      _platform.doListToTagChanged(listToTag);
}

class NoOpFilterChannel with FilterChannel {
  @override
  Future<void> doFiltersChanged(List<Filter> filters) async {}

  @override
  Future<void> doFilterSelectionChanged(List<FilterSelection> filters) async {}

  @override
  Future<void> doListToTagChanged(Map<String, String> listToTag) async {}
}
