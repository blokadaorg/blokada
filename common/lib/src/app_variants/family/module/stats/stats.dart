import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/platform/stats/api.dart' as platform_stats;
import 'package:common/src/platform/stats/model.dart';

export 'package:common/src/platform/stats/model.dart';

part 'actor.dart';
part 'api.dart';
part 'json.dart';

class StatsModule with Module {
  @override
  onCreateModule() async {
    await register(StatsApi());
    await register(StatsActor());
  }
}
