import 'package:collection/collection.dart';
import 'package:common/common/api/api.dart';
import 'package:common/common/defaults/filter_defaults.dart';
import 'package:common/common/model/model.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/core/core.dart';

part 'actor.dart';
part 'api.dart';

class ProfileModule with Module {
  @override
  onCreateModule(Act act) async {
    await register(ProfileApi());
    await register(ProfileActor());
  }
}
