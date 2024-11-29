import 'dart:convert';

import 'package:common/common/api/api.dart';
import 'package:common/core/core.dart';

part 'actor.dart';
part 'api.dart';
part 'json.dart';

class CustomlistModule with Module {
  @override
  onCreateModule(Act act) async {
    await register(CustomlistApi());
    await register(CustomlistActor());
  }
}
