import 'package:common/service/I18nService.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../../stats/stats.dart';
import '../../util/di.dart';
import '../minicard/header.dart';
import '../minicard/minicard.dart';
import '../theme.dart';
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
      child: Column(
        children: [
          const SizedBox(height: 80),
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
          )
        ],
      ),
    );
  }
}
