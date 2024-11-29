import 'package:collection/collection.dart';
import 'package:common/common/module/list/list.dart';
import 'package:common/core/core.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';

part 'actor.dart';
part 'filter_decor_defaults.dart';
part 'filter_decor_model.dart';
part 'filter_defaults.dart';
part 'filter_option_decor_defaults.dart';
part 'mapping.dart';
part 'model.dart';
part 'value.dart';

class FilterModule with Module {
  @override
  onCreateModule(Act act) async {
    await register(KnownFilters(
      isFamily: act.isFamily,
      isIos: act.platform == PlatformType.iOS,
    ));
    await register(DefaultFilters(act.isFamily));

    await register(CurrentConfig());
    await register(SelectedFilters());
    await register(FilterActor());
  }
}
