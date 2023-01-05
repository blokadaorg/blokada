import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';

import '../service/Services.dart';

part 'StageRepo.g.dart';

class StageRepo = _StageRepo with _$StageRepo;

abstract class _StageRepo with Store {

  static const stageChannel = MethodChannel('stage:foreground');

  late final log = Services.instance.log;

  @observable
  bool isForeground = false;

  start() async {
    stageChannel.setMethodCallHandler((call) async {
      try {
        final state = call.arguments as bool;
        if (state != isForeground) {
          isForeground = state;
          log.v("Got Stage state from platform");
        }
      } catch (ex) {
        log.e("Failed to parse Stage state: $ex");
      }
    });
  }

}

