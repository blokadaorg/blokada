import 'dart:async';

import 'package:common/repo/StatsRepo.dart';
import 'package:common/service/I18nService.dart';
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
          sheetService.openSheet(context);
        } else {
          setState(() {
            appRepo.pressedPowerButton();
          });
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.only(top: 32.0, bottom: 24.0),
        child: Column(children: [
          (powerReady && blockedCounter > 0) ?
          Countup(
            begin: previousBlockedCounter,
            end: blockedCounter,
            duration: Duration(milliseconds: 1500),
            style: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w600, color: (appRepo.appState.plus) ? theme.plus : theme.cloud),
          ) : Text("", style: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w600)),
          Padding(
            padding: const EdgeInsets.only(left: 32.0, right: 32.0),
            child: Container(
              alignment: Alignment.center,
              child: (powerReady && blockedCounter > 0) ?
                Text("home status detail active day".i18n + "\n", style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, textAlign: TextAlign.center) :
              (powerReady) ?
                Text("home status detail active".i18n.replaceAll("*", ""), style: Theme.of(context).textTheme.bodyMedium, maxLines: 2) :
              (appRepo.appState.working || appRepo.appState.state == AppState.activated) ?
                Text("home status detail progress".i18n, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2) :
                Text("home action tap to activate".i18n, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2),
            ),
          ),
          AnimatedOpacity(
            opacity: (appModel.plus && powerReady) ? 1 : 0,
            duration: Duration(milliseconds: 1000),
            child: Text("home status detail plus".i18n.replaceAll("*", ""),
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: theme.plus, fontWeight: FontWeight.bold)
            ),
          ),
        ]),
      ),
    );
  }

}
