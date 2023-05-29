import 'dart:async';

import 'package:common/app/pause/pause.dart';
import 'package:common/service/I18nService.dart';
import 'package:common/service/Services.dart';
import 'package:common/service/SheetService.dart';
import 'package:common/stats/stats.dart';
import 'package:countup/countup.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../app/app.dart';
import '../app/channel.pg.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'home/home.dart';
import 'myapp.dart';

class HomeCounter extends StatefulWidget {
  HomeCounter({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }
}

class _HomeCounterState extends State<HomeCounter>
    with TickerProviderStateMixin, TraceOrigin {
  final _app = di<AppStore>();
  final _appPause = di<AppPauseStore>();
  final _stats = di<StatsStore>();
  final _home = di<HomeStore>();

  late SheetService sheetService = Services.instance.sheet;

  bool powerReady = false;
  double blockedCounter = 0.0;
  double previousBlockedCounter = 0.0;

  @override
  void initState() {
    super.initState();

    mobx.autorun((_) {
      final status = _app.status;
      final stats = _stats.stats;
      final powerReady = _home.powerOnAnimationReady;

      setState(() {
        this.powerReady = powerReady;
        blockedCounter = stats.dayBlocked.toDouble();
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
    final status = _app.status;
    return GestureDetector(
      onTap: () {
        if (status.isWorking()) {
          // Do nothing when loading
        } else if (status.isActive()) {
          sheetService.openSheet(context);
        } else {
          setState(() {
            traceAs("fromWidget", (trace) async {
              await _appPause.toggleApp(trace);
            });
          });
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.only(top: 32.0, bottom: 24.0),
        child: Column(children: [
          (powerReady && blockedCounter > 0)
              ? Countup(
                  begin: previousBlockedCounter,
                  end: blockedCounter,
                  duration: Duration(milliseconds: 1500),
                  style: Theme.of(context).textTheme.displaySmall!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: (status == AppStatus.activatedPlus)
                          ? theme.plus
                          : theme.cloud),
                )
              : Text("",
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall!
                      .copyWith(fontWeight: FontWeight.w600)),
          Padding(
            padding: const EdgeInsets.only(left: 32.0, right: 32.0),
            child: Container(
              alignment: Alignment.center,
              child: (powerReady && blockedCounter > 0)
                  ? Text("home status detail active day".i18n + "\n",
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      textAlign: TextAlign.center)
                  : (powerReady)
                      ? Text(
                          "home status detail active".i18n.replaceAll("*", ""),
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2)
                      : (status.isWorking() || status.isActive())
                          ? Text("home status detail progress".i18n,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2)
                          : Text("home action tap to activate".i18n,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2),
            ),
          ),
          AnimatedOpacity(
            opacity: (status == AppStatus.activatedPlus && powerReady) ? 1 : 0,
            duration: Duration(milliseconds: 1000),
            child: Text("home status detail plus".i18n.replaceAll("*", ""),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(color: theme.plus, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}
