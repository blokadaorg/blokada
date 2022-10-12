import 'dart:async';

import 'package:common/repo/StatsRepo.dart';
import 'package:common/service/Services.dart';
import 'package:common/service/SheetService.dart';
import 'package:countup/countup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../main.dart';
import '../model/AppModel.dart';
import '../repo/AppRepo.dart';
import '../repo/Repos.dart';

class HomeCounter extends StatefulWidget {

  HomeCounter({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }

}

class _HomeCounterState extends State<HomeCounter> with TickerProviderStateMixin {

  late AppRepo appRepo = Repos.instance.app;
  late StatsRepo statsRepo = Repos.instance.stats;

  late SheetService sheetService = Services.instance.sheet;

  AppModel appModel = AppModel.empty();
  bool powerReady = false;
  double blockedCounter = 0.0;
  double previousBlockedCounter = 0.0;

  @override
  void initState() {
    super.initState();

    mobx.autorun((_) {
      setState(() {
        appModel = appRepo.appState;
        powerReady = appRepo.powerOnAnimationReady;
        blockedCounter = statsRepo.stats.dayBlocked.toDouble();
        if (powerReady) {
          Timer(Duration(seconds: 5), () {
            previousBlockedCounter = blockedCounter;
          });
        } else {
          previousBlockedCounter = 0;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BrandTheme>()!;
    return GestureDetector(
      onTap: () {
        if (appModel.working) {
          // Do nothing when loading
        } else if (appModel.state == AppState.activated) {
          sheetService.openSheet();
        } else {
          setState(() {
            appRepo.pressedPowerButton();
          });
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 64.0),
          child: (powerReady) ?
          Countup(
            begin: previousBlockedCounter,
            end: blockedCounter,
            duration: Duration(seconds: 5),
            style: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w600, color: (appRepo.appState.plus) ? theme.plus : theme.cloud),
          ) : Text("", style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white)),
        ),
        Container(
          child: (powerReady) ?
            Text("Ads and trackers blocked last 24h", style: Theme.of(context).textTheme.titleMedium) :
          (appRepo.appState.working || appRepo.appState.state == AppState.activated) ?
            Text("Please wait...", style: Theme.of(context).textTheme.titleMedium) :
            Text("Tap to activate", style: Theme.of(context).textTheme.titleMedium),
        ),
        AnimatedOpacity(
          opacity: (appModel.plus && powerReady) ? 1 : 0,
          duration: Duration(milliseconds: 1000),
          child: Text("+ protecting your privacy",
              style: Theme.of(context).textTheme.titleMedium!.copyWith(color: theme.plus, fontWeight: FontWeight.bold)
          ),
        ),
      ]),
    );
  }

}
