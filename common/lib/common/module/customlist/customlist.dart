import 'dart:convert';

import 'package:common/common/api/api.dart';
import 'package:common/core/core.dart';

part 'actor.dart';
part 'api.dart';
part 'json.dart';
part 'value.dart';

class CustomlistModule with Module {
  @override
  onCreateModule() async {
    await register(CustomlistPayloadValue());
    await register(CustomlistApi());
    await register(CustomlistActor());
  }
}
