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
      try {
        final state = AppModel.fromJson(jsonDecode(call.arguments));
        if (state != appState) {
          appState = state;
          print("Got App state from platform");
          print(appState.state.toString());
        }
      } catch (ex) {
        print("Failed to parse App state: $ex");
      }
    });
  }

  pauseApp() {
    _changeState(false);
  }

  unpauseApp() {
    _changeState(true);
  }

  Future<void> _changeState(bool unpause) async {
    try {
      await appChangeStateChannel.invokeMethod('app:changeState', unpause);
    } on Exception catch (e) {
      print("Failed to change app state: '${e}'.");

      // TODO: if debug
      if (appState.state != AppState.activated) {
        print("unpausing - debug");
        appState = AppModel(state: AppState.activated, working: true, plus: false);
        Timer(Duration(seconds: 3), () {
          print("unpaused");
          appState = AppModel(state: AppState.activated, working: false, plus: false);
        });
      } else {
        print("pausing - debug");
        appState = AppModel(state: AppState.paused, working: true, plus: false);
        Timer(Duration(seconds: 2), () {
          appState = AppModel(state: AppState.paused, working: false, plus: false);
        });
      }
    }
  }

}