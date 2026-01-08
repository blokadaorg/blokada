import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';

part 'api.dart';
part 'model.dart';

class ListModule with Module {
  @override
  onCreateModule() async {
    await register(ListApi());
  }
}
