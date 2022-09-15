import 'package:common/ui/column_chart.dart';
import 'package:common/ui/radial_segment.dart';
import 'package:common/ui/selector.dart';
import 'package:common/ui/toplist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:draggable_home/draggable_home.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';

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
  late Future<UiStats> statsFuture;

  @override
  void initState() {
    statsFuture = Repos.instance.stats.getStats("ebwkrlznagkw");
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
              child: listView(),
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

  Widget listView() {
    return FutureBuilder<UiStats>(
      future: statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(
            child: Text(
              "Error: " + error.toString(),
            ),
          );
        } else {
          return ListView.builder(
              padding: const EdgeInsets.only(top: 0),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              shrinkWrap: true,
              itemBuilder: (context, index) => Container(
                  child: getChart(index,
                      snapshot.data!.blocked,
                      snapshot.data!.allowed
                  )
              )
          );
        }
      }
    );
  }

  Widget getChart(int index, int blocked, int allowed) {
    switch (index) {
      // case 1:
      //   return LineChartSample2();
      case 0:
        return Selector();
      case 1:
        return RadialSegment(blocked: blocked, allowed: allowed);
      // case 1:
      //   return PieChartSample2();
      // case 2:
      //   return PieChartSample1();
      case 2:
        return Column(
          children: [
            ColumnChart(),
          ],
        );
      case 3:
        return Container(child: Toplist(red: false));
      default:
        return Container(child: Toplist(red: true));
    }
  }
}
