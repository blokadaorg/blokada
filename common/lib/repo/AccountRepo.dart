import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';

import 'package:common/model/BlockaModel.dart';
import 'package:common/service/BlockaApiService.dart';

import '../model/UiModel.dart';

part 'AccountRepo.g.dart';

class AccountRepo = _AccountRepo with _$AccountRepo;

abstract class _AccountRepo with Store {

  late final BlockaApiService _api = BlockaApiService();

  static const accountIdChannel = MethodChannel('account:id');

  @observable
  String accountId = "";

  start() async {
    accountIdChannel.setMethodCallHandler((call) async {
      print("Got Account ID from platform");
      accountId = call.arguments as String;
      if (accountId.isEmpty) {
        print("Account ID is empty!");
      }
    });
    accountId = "ebwkrlznagkw";
  }

}