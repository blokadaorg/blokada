import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';

part 'StageRepo.g.dart';

class StageRepo = _StageRepo with _$StageRepo;

abstract class _StageRepo with Store {

  static const stageChannel = MethodChannel('stage:foreground');

  @observable
  bool isForeground = false;

  start() async {
    stageChannel.setMethodCallHandler((call) async {
      try {
        final state = call.arguments as bool;
        if (state != isForeground) {
          isForeground = state;
          print("Got Stage state from platform");
        }
      } catch (ex) {
        print("Failed to parse Stage state: $ex");
      }
    });
  }

}

