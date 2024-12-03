import 'dart:convert';

import 'package:common/common/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';

part 'actor.dart';
part 'api.dart';
part 'json.dart';
part 'model.dart';

class StatsModule with Module {
  @override
  onCreateModule() async {
    await register(StatsApi());
    await register(StatsActor());
  }
}
