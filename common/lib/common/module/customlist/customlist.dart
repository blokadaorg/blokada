import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';

part 'actor.dart';
part 'api.dart';

class CustomListsValue extends Value<CustomLists> {
  CustomListsValue() : super(load: () => CustomLists(denied: [], allowed: []));

  reset() => now = CustomLists(denied: [], allowed: []);
}

class CustomlistModule with Module {
  @override
  onCreateModule() async {
    await register(CustomListsValue());
    await register(CustomlistApi());
    await register(CustomlistActor());
  }
}
