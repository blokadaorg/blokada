import 'package:common/ui/column_chart.dart';
import 'package:common/ui/radial_segment.dart';
import 'package:common/ui/totalcounter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../main.dart';
import '../model/UiModel.dart';
import '../repo/Repos.dart';
import '../repo/StatsRepo.dart';

class FrontScreen extends StatefulWidget {

  FrontScreen({Key? key, required bool this.autoRefresh, required ScrollController this.controller}) : super(key: key);

  final bool autoRefresh;
  final ScrollController controller;

  @override
  State<StatefulWidget> createState() => FrontScreenState(autoRefresh: this.autoRefresh, controller: this.controller);

}

class FrontScreenState extends State<FrontScreen> {

  FrontScreenState({required bool this.autoRefresh, required ScrollController this.controller});

  final StatsRepo statsRepo = Repos.instance.stats;

  final bool autoRefresh;
  final ScrollController controller;

  var stats = UiStats.empty();

  @override
  void initState() {
    if (autoRefresh) {
      mobx.autorun((_) {
        setState(() {
          stats = statsRepo.stats;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return content();
  }

  Widget content() {
    final theme = Theme.of(context).extension<BrandTheme>()!;

    return Container(
      decoration: BoxDecoration(color: theme.panelBackground, borderRadius: BorderRadius.circular(10)),
      child: ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [
          RadialSegment(autoRefresh: autoRefresh),
          ColumnChart(stats: stats),
          TotalCounter(autoRefresh: autoRefresh)
        ],
      ),
    );
  }

}
