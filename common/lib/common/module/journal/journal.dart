import 'dart:convert';

import 'package:common/common/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/platform/custom/custom.dart';
import 'package:dartx/dartx.dart';
import 'package:timeago/timeago.dart' as timeago;

part 'actor.dart';
part 'api.dart';
part 'json.dart';
part 'model.dart';
part 'value.dart';

class JournalModule with Module {
  @override
  onCreateModule() async {
    await register(JournalEntriesValue());
    await register(JournalFilterValue());
    await register(JournalDevicesValue());
    await register(JournalApi());
    await register(JournalActor());
  }
}
