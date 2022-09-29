import 'dart:async';

import 'package:common/ui/column_chart.dart';
import 'package:common/ui/radial_segment.dart';
import 'package:common/ui/selector.dart';
import 'package:common/ui/toplist.dart';
import 'package:common/ui/totalcounter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:draggable_home/draggable_home.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:mobx/mobx.dart' as mobx;

import '../model/UiModel.dart';
import '../repo/Repos.dart';
import '../repo/StatsRepo.dart';
import 'home.dart';
import 'samples/pie_chart_sample1.dart';
import 'samples/pie_chart_sample2.dart';
import 'samples/pie_chart_sample3.dart';

class FrontScreen extends StatefulWidget {

  FrontScreen({Key? key, required bool this.autoRefresh}) : super(key: key);

  final bool autoRefresh;

  @override
  State<StatefulWidget> createState() => FrontScreenState(autoRefresh: this.autoRefresh);

}

class FrontScreenState extends State<FrontScreen> {

  FrontScreenState({required bool this.autoRefresh});

  final StatsRepo statsRepo = Repos.instance.stats;

  final bool autoRefresh;
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
      return Container(
        decoration: BoxDecoration(color: Color(0xff1c1c1e)),
        child: ListView(
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
