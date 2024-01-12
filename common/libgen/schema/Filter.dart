import 'package:pigeon/pigeon.dart';

class Filter {
  final String filterName;
  final List<String?> options;

  Filter(this.filterName, this.options);
}

@HostApi()
abstract class FilterOps {
  @async
  void doFiltersChanged(List<Filter> filters);

  @async
  void doFilterSelectionChanged(List<Filter> selections);
}
