import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';

import 'package:common/model/BlockaModel.dart';
import 'package:common/service/BlockaApiService.dart';

import '../model/AppModel.dart';
import '../model/UiModel.dart';

part 'PlusRepo.g.dart';

class PlusRepo = _PlusRepo with _$PlusRepo;

abstract class _PlusRepo with Store {

  static const plusChannel = MethodChannel('plus');

  start() async {
  }

  openLocations() async {
    try {
      await plusChannel.invokeMethod('openLocations');
    } on Exception catch (e) {
      print("Failed to open locations: '$e'.");
    }
  }

  switchPlus(bool on) async {
    try {
      await plusChannel.invokeMethod('switchPlus', on);
    } on Exception catch (e) {
      print("Failed to switchPlus: '$e'.");
    }
  }

}