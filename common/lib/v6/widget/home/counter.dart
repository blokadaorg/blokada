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
import 'package:common/v6/widget/home/home_section.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

class HomeCounter extends StatefulWidget {
  const HomeCounter({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }
}

class _HomeCounterState extends State<HomeCounter> with TickerProviderStateMixin, Logging {
  final _stage = Core.get<StageStore>();
  final _app = Core.get<AppStore>();
  final _stats = Core.get<StatsStore>();

  double counter = 0.0;
  double lastCounter = -1.0;

  @override
  void initState() {
    super.initState();

    mobx.autorun((_) {
      final stats = _stats.stats;

      setState(() {
        if (lastCounter < 0) {
          lastCounter = 0;
        } else {
          lastCounter = counter;
        }
        counter = stats.dayTotal.toDouble();
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
          color: (_app.status == AppStatus.activatedPlus) ? theme.accent : theme.cloud,
          chevronIcon: Icons.bar_chart,
        ),
        big: counter == 0
            ? const Text("...",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ))
            : MiniCardCounter(counter: counter, lastCounter: lastCounter),
        small: "",
        footer: "home status detail active".i18n.replaceAll("*", ""),
      ),
    );
  }
}
