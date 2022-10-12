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

  @observable
  bool powerOnAnimationReady = false;

  start() async {
    appStateChannel.setMethodCallHandler((call) async {
      try {
        final state = AppModel.fromJson(jsonDecode(call.arguments));
        if (state != appState) {
          appState = state;
          print("Got App state from platform");
          print(appState.state.toString());

          if (/*state.working || */state.state != AppState.activated) {
            print("Resetting powerOnAnimationReady flag");
            powerOnAnimationReady = false;
          }
        }
      } catch (ex) {
        print("Failed to parse App state: $ex");
      }
    });
  }

  powerOnIsReady() {
    powerOnAnimationReady = true;
  }

  pressedPowerButton() {
    _changeState();
  }

  Future<void> _changeState() async {
    try {
      await appChangeStateChannel.invokeMethod('app:changeState');
    } on Exception catch (e) {
      print("Failed to change app state: '${e}'.");

      // TODO: if debug
      if (appState.state != AppState.activated) {
        print("unpausing - debug");
        appState = AppModel(state: AppState.activated, working: true, plus: false, location: "");
        Timer(Duration(seconds: 3), () {
          print("unpaused");
          appState = AppModel(state: AppState.activated, working: false, plus: false, location: "");
        });
      } else {
        print("pausing - debug");
        appState = AppModel(state: AppState.paused, working: true, plus: false, location: "");
        Timer(Duration(seconds: 2), () {
          if (!appState.plus) {
            appState = AppModel(state: AppState.activated, working: false, plus: true, location: "Londonia");
          } else {
            appState = AppModel(state: AppState.paused, working: false, plus: false, location: "Londonia");
          }
        });
      }
    }
  }

}