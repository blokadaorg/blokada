import 'dart:async';
import 'dart:math';
import 'package:mobx/mobx.dart';

import 'package:common/model/BlockaModel.dart';
import 'package:common/service/BlockaApiService.dart';

import '../model/AppModel.dart';
import '../model/UiModel.dart';

part 'AppRepo.g.dart';

class AppRepo = _AppRepo with _$AppRepo;

abstract class _AppRepo with Store {

  late final BlockaApiService _api = BlockaApiService();

  @observable
  AppModel appState = AppModel.empty();

  start() async {
  }

  pauseApp() {
    appState = AppModel(state: AppState.paused, working: true, plus: false);
    Timer(Duration(seconds: 2), () {
      appState = AppModel(state: AppState.paused, working: false, plus: false);
    });
  }

  unpauseApp() {
    print("unpausing");
    appState = AppModel(state: AppState.activated, working: true, plus: false);
    Timer(Duration(seconds: 3), () {
      print("unpaused");
      appState = AppModel(state: AppState.activated, working: false, plus: false);
    });
  }

  // Future<AppState> getAppState(String accountId) async {
  //   final stats = await _api.getStats(accountId);
  //   return _convertStats(stats);
  // }

}