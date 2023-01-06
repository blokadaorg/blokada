import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';

import 'package:common/model/BlockaModel.dart';
import 'package:common/service/BlockaApiService.dart';

import '../model/AppModel.dart';
import '../model/UiModel.dart';
import '../service/Services.dart';

part 'PlusRepo.g.dart';

class PlusRepo = _PlusRepo with _$PlusRepo;

abstract class _PlusRepo with Store {

  static const plusChannel = MethodChannel('plus');

  late final log = Services.instance.log;

  start() async {
  }

  openLocations() async {
    try {
      await plusChannel.invokeMethod('openLocations');
    } on Exception catch (e) {
      log.e("Failed to open locations: '$e'.");
    }
  }

  switchPlus(bool on) async {
    try {
      await plusChannel.invokeMethod('switchPlus', on);
    } on Exception catch (e) {
      log.e("Failed to switchPlus: '$e'.");
    }
  }

}