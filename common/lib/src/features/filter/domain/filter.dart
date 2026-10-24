import 'package:collection/collection.dart';
import 'package:common/src/features/list/domain/list.dart';
import 'package:common/src/shared/ui/string.dart';
import 'package:common/src/core/core.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';

part 'actor.dart';
part 'blocklists.dart';
part 'filter_decor_defaults.dart';
part 'filter_decor_model.dart';
part 'filter_defaults.dart';
part 'filter_option_decor_defaults.dart';
part 'mapping.dart';
part 'model.dart';

class CurrentConfig extends NullableAsyncValue<UserFilterConfig> {
  CurrentConfig() : super(sensitive: true);
}

/// The main blocklist the user picked on the v6 blocklists screen, like
/// "oisd/small". Only needed when several general lists are on, so the
/// screen keeps showing the same one as main after a restart.
class BlocklistMainPick extends StringPersistedValue {
  BlocklistMainPick() : super("filter:main", sensitive: false);
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
    ));
    await register(DefaultFilters(Core.act.isFamily));

    await register(CurrentConfig());
    await register(SelectedFilters());
    await register(BlocklistMainPick());
    await register(FilterActor());
  }
}
