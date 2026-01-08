import 'package:collection/collection.dart';
import 'package:common/src/features/list/domain/list.dart';
import 'package:common/src/shared/ui/string.dart';
import 'package:common/src/core/core.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';

part 'actor.dart';
part 'filter_decor_defaults.dart';
part 'filter_decor_model.dart';
part 'filter_defaults.dart';
part 'filter_option_decor_defaults.dart';
part 'mapping.dart';
part 'model.dart';

class CurrentConfig extends NullableAsyncValue<UserFilterConfig> {
  CurrentConfig() : super(sensitive: true);
}

class SelectedFilters extends AsyncValue<List<FilterSelection>> {
  SelectedFilters() : super(sensitive: true) {
    load = (Marker m) async => <FilterSelection>[];
  }
}

class FilterModule with Module {
  @override
  onCreateModule() async {
    await register(KnownFilters(
      isFamily: Core.act.isFamily,
      isIos: Core.act.isIos,
    ));
    await register(DefaultFilters(Core.act.isFamily));

    await register(CurrentConfig());
    await register(SelectedFilters());
    await register(FilterActor());
  }
}
