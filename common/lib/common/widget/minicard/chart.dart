import 'dart:math';

import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/util/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class MiniCardChart extends StatelessWidget {
  final UiStats stats;
  final Color color;
  final bool animate;
  final double? height;

  const MiniCardChart({
    super.key,
    required this.stats,
    required this.color,
    this.animate = true,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      //decoration: BoxDecoration(color: Colors.greenAccent),
      child: (stats.totalAllowed > 0)
          ? _ColumnChart(stats: stats, color: color, animate: animate, height: height)
          : SizedBox(
              height: height ?? 90,
              //constraints: const BoxConstraints(maxHeight: 90),
              child: // Container(),
                  Center(child: Text("universal status waiting for data".i18n)),
              // Column(
              // mainAxisAlignment: MainAxisAlignment.end,
              // children: [
              //   Text("Blokada is turned off for Alva"),
              // ],
              // ),
            ),
    );
  }
}

class _ColumnChart extends StatelessWidget {
  final Color color;
  final UiStats stats;
  final bool animate;
  final double? height;

  _ColumnChart({
    Key? key,
    required this.stats,
    required this.color,
    required this.animate,
    this.height,
  }) : super(key: key) {
    _compute();
  }

  late List<_ChartData> dataGreen;
  late double minGreen;
  late double maxGreen;
  late double oldestEntry;
  late DateTime latestTimestamp;

  void _compute() {
    latestTimestamp =
        DateTime.fromMillisecondsSinceEpoch(stats.latestTimestamp);

    dataGreen = stats.allowedHistogram
        .asMap()
        .entries
        .map((entry) => _ChartData(
            latestTimestamp.subtract(Duration(hours: 23 - entry.key)),
            entry.value * 1))
        .toList();

    maxGreen = 10; // Max Y axis value
    //minGreen = 1000;
    minGreen = 0;
    oldestEntry = -24; // Min X axis value
    for (var i = 0; i < 24 && i < stats.allowedHistogram.length; i++) {
      final green = stats.allowedHistogram[i];
      final red = stats.blockedHistogram[i];
      if (green * 1.05 > maxGreen) maxGreen = green * 1.05;
      if (green * 0.8 < minGreen) minGreen = max(0, green * 0.8);
      // Skip consecutive zero bars at the beginning and shrink scale
      if (maxGreen == 0 && oldestEntry.abs() == (24 - i) && oldestEntry < -6)
        oldestEntry += 1;
    }
  }

  List<double> stops = <double>[0.3, 0.7];

  @override
  Widget build(BuildContext context) {
    _compute();

    List<Color> colorsGreen = <Color>[
      color,
      color.darken(20),
    ];

    return Container(
      constraints: BoxConstraints(maxHeight: height ?? 90),
      child: SfCartesianChart(
        margin: const EdgeInsets.all(0),
        plotAreaBorderWidth: 0,
        primaryXAxis: DateTimeAxis(
          minimum: latestTimestamp.subtract(Duration(hours: 23)),
          maximum: latestTimestamp,
          interval: (oldestEntry.abs() / 4).ceilToDouble(),
          isVisible: false,
        ),
        primaryYAxis: NumericAxis(
          minimum: -10,
          maximum: max(maxGreen, 50),
          interval: (maxGreen ~/ 3).toDouble(),
          majorGridLines: const MajorGridLines(width: 0),
          isVisible: false,
        ),
        tooltipBehavior: TooltipBehavior(enable: false),
        enableSideBySideSeriesPlacement: false,
        enableAxisAnimation: animate,
        series: [
          SplineSeries<_ChartData, DateTime>(
            animationDuration: animate ? 2000 : 0,
            dataSource: dataGreen,
            xValueMapper: (_ChartData data, _) => data.x,
            yValueMapper: (_ChartData data, _) => data.y,
            splineType: SplineType.monotonic,
            color: color,
            width: 3, // Line width
          )
          // ColumnSeries<_ChartData, DateTime>(
          //   dataSource: dataGreen,
          //   xValueMapper: (_ChartData sales, _) => sales.x,
          //   yValueMapper: (_ChartData sales, _) => sales.y,
          //   name: "stats label allowed".i18n,
          //   color: colorsGreen[0],
          //   width: 0.8,
          //   animationDuration: 1000,
          //   borderRadius: const BorderRadius.only(
          //       topLeft: Radius.circular(4), topRight: Radius.circular(4)),
          //   gradient: LinearGradient(
          //       begin: Alignment.topCenter,
          //       end: Alignment.bottomCenter,
          //       colors: colorsGreen,
          //       stops: stops),
          // ),
        ],
      ),
    );
  }
}

class _ChartData {
  _ChartData(this.x, this.y);

  final DateTime x;
  final int y;
}
