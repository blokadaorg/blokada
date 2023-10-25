import 'dart:async';
import 'dart:math';

import 'package:common/service/I18nService.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../../app/app.dart';
import '../../app/channel.pg.dart';
import '../../family/famdevice/famdevice.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../stats/stats.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../minicard/chart.dart';
import '../minicard/counter.dart';
import '../minicard/header.dart';
import '../minicard/minicard.dart';
import '../minicard/summary.dart';
import '../theme.dart';

class HomeDevice extends StatefulWidget {
  final void Function()? onLongPress;
  final String deviceName;
  final FamilyDevice device;
  final bool thisDevice;
  final Color color;

  HomeDevice({
    Key? key,
    this.onLongPress,
    required this.deviceName,
    required this.device,
    required this.thisDevice,
    required this.color,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }
}

class _HomeCounterState extends State<HomeDevice>
    with TickerProviderStateMixin, TraceOrigin {
  final _stage = dep<StageStore>();
  final _app = dep<AppStore>();
  final _stats = dep<StatsStore>();

  double blockedCounter = 0.0;
  double previousBlockedCounter = 0.0;

  @override
  void initState() {
    super.initState();

    mobx.autorun((_) {
      final status = _app.status;
      final stats = _stats.stats;

      setState(() {
        blockedCounter = stats.dayBlocked.toDouble();
        blockedCounter = Random().nextInt(1000).toDouble();
        Timer(Duration(seconds: 5), () {
          previousBlockedCounter = blockedCounter;
        });
      });
    });
  }

  _onTap() {
    traceAs("tappedSlideToStats", (trace) async {
      await _stats.setSelectedDevice(trace, widget.device.deviceName);
      await _stage.setRoute(trace, StageKnownRoute.homeStats.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: MiniCard(
        onTap: _onTap,
        // outlined: widget.thisDevice,
        outlined: false,
        child: MiniCardSummary(
          header: MiniCardHeader(
            text: widget.deviceName,
            icon: Icons.phone_iphone,
            color: widget.color,
            chevronIcon: Icons.chevron_right,
          ),
          big: MiniCardChart(device: widget.device, color: widget.color),
          small: "",
          //footer: "home status detail active".i18n.replaceAll("*", ""),
        ),
      ),
    );
  }
}
