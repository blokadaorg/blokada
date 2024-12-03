import 'dart:async';

import 'package:common/common/widget/minicard/counter.dart';
import 'package:common/common/widget/minicard/header.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/minicard/summary.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:common/v6/widget/home/home.dart';
import 'package:common/v6/widget/home/home_section.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

class HomeCounter2 extends StatefulWidget {
  HomeCounter2({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }
}

class _HomeCounterState extends State<HomeCounter2>
    with TickerProviderStateMixin, Logging {
  final _stage = Core.get<StageStore>();
  final _app = Core.get<AppStore>();
  final _stats = Core.get<StatsStore>();
  final _home = Core.get<HomeStore>();

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
    _stage.setRoute(pathHomeStats, Markers.userTap);
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
