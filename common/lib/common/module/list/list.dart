import 'dart:convert';

import 'package:common/common/api/api.dart';
import 'package:common/core/core.dart';

part 'api.dart';
part 'json.dart';
part 'model.dart';

class ListModule with Module {
  @override
  onCreateModule() async {
    await register(ListApi());
  }
}
