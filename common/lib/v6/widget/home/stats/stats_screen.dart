import 'package:common/common/i18n.dart';
import 'package:common/common/model.dart';
import 'package:common/common/widget/minicard/header.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/stats/stats.dart';
import 'package:common/util/di.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:relative_scale/relative_scale.dart';

import 'column_chart.dart';
import 'radial_segment.dart';
import 'totalcounter.dart';

class StatsScreen extends StatefulWidget {
  StatsScreen(
      {Key? key,
      required bool this.autoRefresh,
      required ScrollController this.controller})
      : super(key: key);

  final bool autoRefresh;
  final ScrollController controller;

  @override
  State<StatefulWidget> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  final _store = dep<StatsStore>();

  var stats = UiStats.empty();

  @override
  void initState() {
    super.initState();
    if (widget.autoRefresh) {
      mobx.autorun((_) {
        setState(() {
          stats = _store.stats;
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
      decoration: BoxDecoration(
        color: theme.bgColor,
      ),
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
