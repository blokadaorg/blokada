import 'package:collection/collection.dart';
import 'package:common/common/defaults/filter_decor_defaults.dart';
import 'package:common/common/defaults/filter_defaults.dart';
import 'package:common/common/model/model.dart';
import 'package:common/common/module/list/list.dart';
import 'package:common/core/core.dart';
import 'package:dartx/dartx.dart';

part 'actor.dart';
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
