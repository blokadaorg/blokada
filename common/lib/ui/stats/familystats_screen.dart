import 'package:common/service/I18nService.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:relative_scale/relative_scale.dart';
import 'dart:math' as math;

import '../../stats/stats.dart';
import '../../util/di.dart';
import '../../util/mobx.dart';
import '../minicard/header.dart';
import '../minicard/minicard.dart';
import '../theme.dart';
import 'column_chart.dart';
import 'radial_segment.dart';
import 'totalcounter.dart';

class FamilyStatsScreen extends StatefulWidget {
  FamilyStatsScreen(
      {Key? key,
      required bool this.autoRefresh,
      required ScrollController this.controller})
      : super(key: key);

  final bool autoRefresh;
  final ScrollController controller;

  @override
  State<StatefulWidget> createState() => FamilyStatsScreenState();
}

class FamilyStatsScreenState extends State<FamilyStatsScreen> {
  final _store = dep<StatsStore>();

  var stats = UiStats.empty();

  @override
  void initState() {
    super.initState();
    setState(() {
      stats = _store.statsForSelectedDevice();
    });

    if (widget.autoRefresh) {
      reactionOnStore((_) => _store.deviceStatsChangesCounter, (_) async {
        setState(() {
          stats = _store.statsForSelectedDevice();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return content();
  }

  Widget content() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Container(
      child: RelativeBuilder(builder: (context, height, width, sy, sx) {
        return Column(
          children: [
            const SizedBox(height: 42),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: MiniCard(
                child: Column(
                  children: [
                    MiniCardHeader(
                      text: "stats header day".i18n,
                      icon: Icons.timelapse,
                      color: theme.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    RadialSegment(autoRefresh: widget.autoRefresh),
                    const SizedBox(height: 16),
                    const Divider(),
                    ColumnChart(stats: stats),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TotalCounter(autoRefresh: widget.autoRefresh),
            ),
            const Spacer(),
            SizedBox(height: sy(60)),
          ],
        );
      }),
    );
  }
}
