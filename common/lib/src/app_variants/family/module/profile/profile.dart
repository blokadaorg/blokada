import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/core/core.dart';
import 'package:dartx/dartx.dart';

part 'actor.dart';
part 'api.dart';
part 'json.dart';

class ProfileModule with Module {
  @override
  onCreateModule() async {
    await register(ProfileApi());
    await register(ProfileActor());
  }
}
