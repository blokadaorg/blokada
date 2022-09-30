import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';

import 'package:common/model/BlockaModel.dart';
import 'package:common/service/BlockaApiService.dart';

import '../model/AppModel.dart';
import '../model/UiModel.dart';

part 'AppRepo.g.dart';

class AppRepo = _AppRepo with _$AppRepo;

abstract class _AppRepo with Store {

  late final BlockaApiService _api = BlockaApiService();

  static const appStateChannel = MethodChannel('app:state');
  static const appChangeStateChannel = MethodChannel('app:changeState');

  @observable
  AppModel appState = AppModel.empty();

  start() async {
    appStateChannel.setMethodCallHandler((call) async {
      print("Got App state from platform");
      try {
        appState = AppModel.fromJson(jsonDecode(call.arguments));
        print(appState.state.toString());
      } catch (ex) {
        print("Failed to parse App state: $ex");
      }
    });
  }

  pauseApp() {
    _changeState(false);
    // appState = AppModel(state: AppState.paused, working: true, plus: false);
    // Timer(Duration(seconds: 2), () {
    //   appState = AppModel(state: AppState.paused, working: false, plus: false);
    // });
  }

  unpauseApp() {
    _changeState(true);
    // print("unpausing");
    // appState = AppModel(state: AppState.activated, working: true, plus: false);
    // Timer(Duration(seconds: 3), () {
    //   print("unpaused");
    //   appState = AppModel(state: AppState.activated, working: false, plus: false);
    // });
  }

  Future<void> _changeState(bool unpause) async {
    try {
      await appChangeStateChannel.invokeMethod('app:changeState', unpause);
    } on PlatformException catch (e) {
      print("Failed to change app state: '${e.message}'.");
    }
  }

}