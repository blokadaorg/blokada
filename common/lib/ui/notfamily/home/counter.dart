import 'dart:async';

import 'package:common/common/i18n.dart';
import 'package:common/util/trace.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../../../app/app.dart';
import '../../../app/channel.pg.dart';
import '../../../common/widget/minicard/counter.dart';
import '../../../common/widget/minicard/header.dart';
import '../../../common/widget/minicard/minicard.dart';
import '../../../common/widget/minicard/summary.dart';
import '../../../common/widget/theme.dart';
import '../../../stage/stage.dart';
import '../../../stats/stats.dart';
import '../../../util/di.dart';
import 'home.dart';
import 'home_screen.dart';

class HomeCounter2 extends StatefulWidget {
  HomeCounter2({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }
}

class _HomeCounterState extends State<HomeCounter2>
    with TickerProviderStateMixin, TraceOrigin {
  final _stage = dep<StageStore>();
  final _app = dep<AppStore>();
  final _stats = dep<StatsStore>();
  final _home = dep<HomeStore>();

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

  _onTap() {
    traceAs("tappedSlideToStats", (trace) async {
      await _stage.setRoute(trace, pathHomeStats);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return MiniCard(
      onTap: _onTap,
      outlined: true,
      child: MiniCardSummary(
        header: MiniCardHeader(
          text: "stats header day".i18n,
          icon: Icons.shield_outlined,
          color: (_app.status == AppStatus.activatedPlus)
              ? theme.accent
              : theme.cloud,
          chevronIcon: Icons.bar_chart,
        ),
        big: MiniCardCounter(counter: blockedCounter),
        small: "",
        footer: "home status detail active".i18n.replaceAll("*", ""),
      ),
    );
  }
}
