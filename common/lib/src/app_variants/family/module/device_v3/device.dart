import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:unique_names_generator/unique_names_generator.dart' as names;

part 'actor.dart';
part 'api.dart';
part 'generator.dart';
part 'json.dart';
part 'model.dart';
part 'value.dart';

class DeviceModule with Module {
  @override
  onCreateModule() async {
    await register(CurrentToken());
    await register(SelectedDeviceTag());
    await register(SlidableOnboarding());
    await register(NameGenerator());
    await register(ThisDevice());
    await register(DeviceApi());
    await register(DeviceActor());
  }
}
