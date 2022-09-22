import 'dart:async';

import 'package:common/ui/column_chart.dart';
import 'package:common/ui/radial_segment.dart';
import 'package:common/ui/selector.dart';
import 'package:common/ui/toplist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:draggable_home/draggable_home.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../model/UiModel.dart';
import '../repo/Repos.dart';
import 'home.dart';
import 'samples/pie_chart_sample1.dart';
import 'samples/pie_chart_sample2.dart';
import 'samples/pie_chart_sample3.dart';

class FrontScreen extends StatefulWidget {

  FrontScreen({Key? key}) : super(key: key);

  final stats = Repos.instance.stats;

  @override
  State<StatefulWidget> createState() => FrontScreenState();

}

class FrontScreenState extends State<FrontScreen> {

  @override
  void initState() {
  }

  @override
  Widget build(BuildContext context) {
    return DraggableHome(
      title: const Text("BLOKADA"),
      actions: [
      ],
      headerExpandedHeight: 0.9,
      headerWidget: Home(),
      headerBottomBar: headerBottomBarWidget(),
      body: [
        Container(
            decoration: new BoxDecoration(color: Color(0xFF111111)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: content(),
            ),
        )
      ],
      stretchMaxHeight: 0.94,
      stretchTriggerOffset: 0.5,
      fullyStretchable: false,
      expandedBody: Home(),
      backgroundColor: Color(0xFF111111),
      appBarColor: Colors.black,
    );
  }

  Row headerBottomBarWidget() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        Icon(
          Icons.settings,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget headerWidget(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          "BLOKADA",
          style: Theme.of(context)
              .textTheme
              .headline1!
              .copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget content() {
    return VisibilityDetector(key: const Key("frontscreen"),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0.4) {
          widget.stats.setFrequentRefresh(true);
        } else {
          widget.stats.setFrequentRefresh(false);
          //cachedStats = UiStats.empty();
        }
      },
      child: Observer (
        builder: (BuildContext context) {
          return Column(
            children: [
              Selector(),
              RadialSegment(stats: widget.stats.stats),
              ColumnChart(stats: widget.stats.stats),
            ]
          );
        },
      )
    );
  }

}
