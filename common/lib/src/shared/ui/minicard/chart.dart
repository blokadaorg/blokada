import 'dart:math';

import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/stats/stats.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class MiniCardChart extends StatelessWidget {
  final UiStats stats;
  final Color color;
  final bool animate;
  final double? height;
  final List<int>? seriesValues;
  final DateTime? seriesEnd;
  final Duration? seriesStep;
  final double minYAxisMax;

  const MiniCardChart({
    super.key,
    required this.stats,
    required this.color,
    this.animate = true,
    this.height,
    this.seriesValues,
    this.seriesEnd,
    this.seriesStep,
    this.minYAxisMax = 50,
  });

  @override
  Widget build(BuildContext context) {
    final hasSeriesOverride = seriesValues != null && seriesValues!.isNotEmpty;
    return GestureDetector(
      //decoration: BoxDecoration(color: Colors.greenAccent),
      child: (stats.totalAllowed > 0 || hasSeriesOverride)
          ? _ColumnChart(
              stats: stats,
              color: color,
              animate: animate,
              height: height,
              seriesValues: seriesValues,
              seriesEnd: seriesEnd,
              seriesStep: seriesStep,
              minYAxisMax: minYAxisMax,
            )
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
  final List<int>? seriesValues;
  final DateTime? seriesEnd;
  final Duration? seriesStep;
  final double minYAxisMax;

  _ColumnChart({
    Key? key,
    required this.stats,
    required this.color,
    required this.animate,
    this.height,
    this.seriesValues,
    this.seriesEnd,
    this.seriesStep,
    required this.minYAxisMax,
  }) : super(key: key) {
    _compute();
  }

  late List<_ChartData> dataGreen;
  late double minGreen;
  late double maxGreen;
  late double oldestEntry;
  late DateTime latestTimestamp;
  late Duration step;
  late List<int> values;

  Duration scaleStep(int multiplier) =>
      Duration(seconds: step.inSeconds * multiplier);

  void _compute() {
    values = seriesValues ?? stats.allowedHistogram;
    latestTimestamp =
        seriesEnd ?? DateTime.fromMillisecondsSinceEpoch(stats.latestTimestamp);
    step = seriesStep ?? const Duration(hours: 1);

    dataGreen = values
        .asMap()
        .entries
        .map((entry) => _ChartData(
            latestTimestamp.subtract(scaleStep(values.length - 1 - entry.key)),
            entry.value * 1))
        .toList();

    maxGreen = 10; // Max Y axis value
    //minGreen = 1000;
    minGreen = 0;
    oldestEntry = -values.length.toDouble(); // Min X axis value
    for (var i = 0; i < values.length; i++) {
      final green = values[i];
      if (green * 1.05 > maxGreen) maxGreen = green * 1.05;
      if (green * 0.8 < minGreen) minGreen = max(0, green * 0.8);
      // Skip consecutive zero bars at the beginning and shrink scale
      if (maxGreen == 0 &&
          oldestEntry.abs() == (values.length - i) &&
          oldestEntry < -6)
        oldestEntry += 1;
    }
  }

  List<double> stops = <double>[0.3, 0.7];

  @override
  Widget build(BuildContext context) {
    _compute();

    return Container(
      constraints: BoxConstraints(maxHeight: height ?? 90),
      child: SfCartesianChart(
        margin: const EdgeInsets.all(0),
        plotAreaBorderWidth: 0,
        primaryXAxis: DateTimeAxis(
          minimum: latestTimestamp.subtract(scaleStep(values.length - 1)),
          maximum: latestTimestamp,
          interval: (oldestEntry.abs() / 4).ceilToDouble(),
          isVisible: false,
        ),
        primaryYAxis: NumericAxis(
          minimum: -10,
          maximum: max(maxGreen, minYAxisMax),
          interval: (max(maxGreen, minYAxisMax) / 3).ceilToDouble(),
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
