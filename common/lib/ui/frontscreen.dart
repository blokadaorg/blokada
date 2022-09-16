import 'dart:async';

import 'package:common/ui/column_chart.dart';
import 'package:common/ui/radial_segment.dart';
import 'package:common/ui/selector.dart';
import 'package:common/ui/toplist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:draggable_home/draggable_home.dart';
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

  const FrontScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => FrontScreenState();

}

class FrontScreenState extends State<FrontScreen> {
  UiStats cachedStats = UiStats.empty();
  Future<UiStats> statsFuture = Future.value(UiStats.empty());
  Timer? timer;

  @override
  void initState() {
  }

  void _startRefreshingStats() {
    if (timer == null) {
      _refreshStats();
      timer = Timer.periodic(const Duration(seconds: 5), (Timer t) => _refreshStats());
    }
  }

  void _stopRefreshingStats() {
    timer?.cancel();
    timer = null;
  }

  void _refreshStats() {
    setState(() {
      statsFuture = Repos.instance.stats.getStats("ebwkrlznagkw");
    });
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
      fullyStretchable: true,
      expandedBody: const Home(),
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
          _startRefreshingStats();
        } else {
          _stopRefreshingStats();
          cachedStats = UiStats.empty();
        }
      },
      child: FutureBuilder(
        future: statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Column(
              children: [
                Selector(),
                RadialSegment(stats: cachedStats),
                ColumnChart(stats: cachedStats),
              ]
            );
          } else if (snapshot.hasError || snapshot.data == null) {
            return Column(
              children: [
                Text("Error: ${snapshot.error}"),
                Selector(),
                RadialSegment(stats: cachedStats),
                ColumnChart(stats: cachedStats),
          ]
            );
          } else {
            cachedStats = snapshot.data as UiStats;

            return Column(
              children: [
                Selector(),
                RadialSegment(stats: cachedStats),
                ColumnChart(stats: cachedStats),
              ]
            );
          }
      })
    );
  }

}
