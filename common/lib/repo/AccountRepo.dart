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

  static const accountIdChannel = MethodChannel('account');

  @observable
  String accountId = "";

  @observable
  String accountType = "Libre";

  start() async {
    accountIdChannel.setMethodCallHandler((call) async {
      if (call.method == "id") {
        print("Got Account ID from platform");
        accountId = call.arguments as String;
        if (accountId.isEmpty) {
          print("Account ID is empty!");
        }
      } else if (call.method == "type") {
        print("Got Account type from platform");
        accountType = call.arguments as String;
        if (accountType.isEmpty) {
          print("Account type is empty!");
        }
      }
    });
    accountId = "ebwkrlznagkw";
  }

}