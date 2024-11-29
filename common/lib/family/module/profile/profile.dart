import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/common/api/api.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/core/core.dart';
import 'package:dartx/dartx.dart';

part 'actor.dart';
part 'api.dart';
part 'json.dart';

class ProfileModule with Module {
  @override
  onCreateModule(Act act) async {
    await register(ProfileApi());
    await register(ProfileActor());
  }
}
