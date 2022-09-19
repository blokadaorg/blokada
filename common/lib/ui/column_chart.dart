import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:common/model/UiModel.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ColumnChart extends StatelessWidget {

  final UiStats stats;

  ColumnChart({
    Key? key, required this.stats
  }) : super(key: key) {
    _compute();
  }

  late List<_ChartData> dataRed;
  late List<_ChartData> dataGreen;
  late double minGreen;
  late double maxGreen;
  late double maxRed;
  late double oldestEntry;
  late DateTime latestTimestamp;

  ChartSeriesController? _chartSeriesController;

  void _compute() {
    // data = [
    //   _ChartData('All', 30, const Color(0xff808080)),
    //   _ChartData('Allowed', 21, const Color(0xff33c75a)),
    //   _ChartData('Blocked', 9, const Color(0xffff3b30)),
    // ];
    latestTimestamp = DateTime.fromMillisecondsSinceEpoch(stats.latestTimestamp);
    dataRed = stats.blockedHistogram.asMap().entries.map((entry) =>
      _ChartData(latestTimestamp.subtract(Duration(hours: 23 - entry.key)), entry.value * 1)
    ).toList();

    dataGreen = stats.allowedHistogram.asMap().entries.map((entry) =>
      _ChartData(latestTimestamp.subtract(Duration(hours: 23 - entry.key)), entry.value * 1)
    ).toList();

    maxRed = 10; // Max Y axis value
    maxGreen = 10; // Max Y axis value
    //minGreen = 1000;
    minGreen = 0;
    oldestEntry = -24; // Min X axis value
    for(var i = 0; i < 24 && i < stats.allowedHistogram.length; i++) {
      final green = stats.allowedHistogram[i];
      final red = stats.blockedHistogram[i];
      if (green * 1.05 > maxGreen) maxGreen = green * 1.05;
      if (red * 1.05 > maxRed) maxRed = red * 1.05;
      if (green * 0.8 < minGreen) minGreen = max(0, green * 0.8);
      // Skip consecutive zero bars at the beginning and shrink scale
      if (maxGreen == 0 && oldestEntry.abs() == (24 - i) && oldestEntry < -6) oldestEntry += 1;
    }

  }




  List<Color> colors = <Color>[
    const Color(0xffA0A0A0),
    const Color(0xff9f9f9f),
  ];
  List<Color> colorsRed = <Color>[
    const Color(0xffff3b30),
    const Color(0xffde342a),
  ];

  List<Color> colorsGreen = <Color>[
    const Color(0xff33c75a),
    const Color(0xff1cab42),
  ];

  List<double> stops = <double>[
    0.3,
    0.7
  ];

  @override
  Widget build(BuildContext context) {
    _compute();
    Timer(Duration(seconds: 5), () {
      _chartSeriesController?.animate();
    });

    return Column(
      children: [
        Container(
            height: 150,
            padding: EdgeInsets.only(left: 8, right: 8),
            child: SfCartesianChart(
              margin: EdgeInsets.all(0),
              plotAreaBorderWidth: 0,
              // primaryXAxis: NumericAxis(
              //     minimum: oldestEntry, maximum: 1, interval: (oldestEntry.abs() / 3).ceilToDouble(),
              //     labelStyle: TextStyle(color: Color(0xff404040))
              // ),
              primaryXAxis: DateTimeAxis(
                  minimum: latestTimestamp.subtract(Duration(hours: oldestEntry.abs().toInt())), maximum: latestTimestamp.add(Duration(hours: 1)),
                  interval: (oldestEntry.abs() / 4).ceilToDouble(),
                  labelStyle: TextStyle(color: Color(0xff404040))
              ),
              primaryYAxis: CategoryAxis(
                  minimum: minGreen, maximum: maxGreen, interval: (maxGreen ~/ 3).toDouble(),
                  majorGridLines: MajorGridLines(width: 0),
                  opposedPosition: true,
                  labelStyle: TextStyle(color: Color(0xff404040))
              ),
              tooltipBehavior: TooltipBehavior(enable: true),
              enableSideBySideSeriesPlacement: false,
              enableAxisAnimation: true,
              series: [
                ColumnSeries<_ChartData, DateTime>(
                  dataSource: dataGreen,
                  xValueMapper: (_ChartData sales, _) => sales.x,
                  yValueMapper: (_ChartData sales, _) => sales.y,
                  name: 'Allowed',
                  color: colorsGreen[0],
                  animationDuration: 1000,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: colorsGreen, stops: stops
                  ),
                ),
              ],
            )
        ),
        Container(
            height: 150,
            padding: EdgeInsets.only(left: 8, right: 8),
            child: SfCartesianChart(
              margin: EdgeInsets.all(0),
              plotAreaBorderWidth: 0,
              // primaryXAxis: NumericAxis(
              //     minimum: oldestEntry, maximum: 1, interval: (oldestEntry.abs() / 3).ceilToDouble(),
              //     labelStyle: TextStyle(color: Color(0xff404040))
              // ),
              primaryXAxis: DateTimeAxis(
                  minimum: latestTimestamp.subtract(Duration(hours: oldestEntry.abs().toInt())), maximum: latestTimestamp.add(Duration(hours: 1)),
                  interval: (oldestEntry.abs() / 4).ceilToDouble(),
                  labelStyle: TextStyle(color: Color(0xff404040))
              ),
              primaryYAxis: CategoryAxis(
                  minimum: 0, maximum: maxRed, interval: (maxRed ~/ 3).toDouble(),
                  majorGridLines: MajorGridLines(width: 0),
                  opposedPosition: true,
                  labelStyle: TextStyle(color: Color(0xff404040))
              ),
              tooltipBehavior: TooltipBehavior(enable: true),
              enableSideBySideSeriesPlacement: false,
              enableAxisAnimation: true,
              series: [
                ColumnSeries<_ChartData, DateTime>(
                  dataSource: dataRed,
                  xValueMapper: (_ChartData sales, _) => sales.x,
                  yValueMapper: (_ChartData sales, _) => sales.y,
                  name: 'Blocked',
                  color: colorsRed[0],
                  animationDuration: 2000,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: colorsRed, stops: stops
                  ),
                ),
              ],
            )
        ),
      ],
    );
  }

}

class _ChartData {
  _ChartData(this.x, this.y);

  final DateTime x;
  final int y;
}
