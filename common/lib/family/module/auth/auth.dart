import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/platform/stage/stage.dart';

part 'actor.dart';
part 'api.dart';
part 'json.dart';

class AuthModule with Module {
  @override
  onCreateModule() async {
    await register(AuthApi());
    await register(AuthActor());
  }
}
