import 'dart:math' as math;
import 'package:common/service/I18nService.dart';
import 'package:common/util/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:relative_scale/relative_scale.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../family/model.dart';
import '../../stats/stats.dart';

class MiniCardChart extends StatelessWidget {
  final FamilyDevice device;
  final Color color;

  const MiniCardChart({
    super.key,
    required this.device,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      //decoration: BoxDecoration(color: Colors.greenAccent),
      child: (device.deviceName.isNotEmpty && device.stats.totalAllowed > 0)
          ? ColumnChart(stats: device.stats, color: color)
          : Text("Waiting for data"),
    );
  }
}

class ColumnChart extends StatelessWidget {
  final Color color;
  final UiStats stats;

  ColumnChart({
    Key? key,
    required this.stats,
    required this.color,
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

  void _compute() {
    // data = [
    //   _ChartData('All', 30, const Color(0xff808080)),
    //   _ChartData('Allowed', 21, const Color(0xff33c75a)),
    //   _ChartData('Blocked', 9, const Color(0xffff3b30)),
    // ];
    latestTimestamp =
        DateTime.fromMillisecondsSinceEpoch(stats.latestTimestamp);
    dataRed = stats.blockedHistogram
        .asMap()
        .entries
        .map((entry) => _ChartData(
            latestTimestamp.subtract(Duration(hours: 23 - entry.key)),
            entry.value * 1))
        .toList();

    dataGreen = stats.allowedHistogram
        .asMap()
        .entries
        .map((entry) => _ChartData(
            latestTimestamp.subtract(Duration(hours: 23 - entry.key)),
            entry.value * 1))
        .toList();

    maxRed = 10; // Max Y axis value
    maxGreen = 10; // Max Y axis value
    //minGreen = 1000;
    minGreen = 0;
    oldestEntry = -24; // Min X axis value
    for (var i = 0; i < 24 && i < stats.allowedHistogram.length; i++) {
      final green = stats.allowedHistogram[i];
      final red = stats.blockedHistogram[i];
      if (green * 1.05 > maxGreen) maxGreen = green * 1.05;
      if (red * 1.05 > maxRed) maxRed = red * 1.05;
      if (green * 0.8 < minGreen) minGreen = math.max(0, green * 0.8);
      // Skip consecutive zero bars at the beginning and shrink scale
      if (maxGreen == 0 && oldestEntry.abs() == (24 - i) && oldestEntry < -6)
        oldestEntry += 1;
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

  List<double> stops = <double>[0.3, 0.7];

  @override
  Widget build(BuildContext context) {
    _compute();

    List<Color> colorsGreen = <Color>[
      color,
      color.darken(20),
    ];

    return RelativeBuilder(builder: (context, height, width, sy, sx) {
      final size = math.min(sy(40), 150.0);
      return Column(
        children: [
          Container(
              height: size,
              padding: EdgeInsets.only(left: 8, right: 8),
              child: SfCartesianChart(
                margin: EdgeInsets.all(0),
                plotAreaBorderWidth: 0,
                // primaryXAxis: NumericAxis(
                //     minimum: oldestEntry, maximum: 1, interval: (oldestEntry.abs() / 3).ceilToDouble(),
                //     labelStyle: TextStyle(color: Color(0xff404040))
                // ),
                primaryXAxis: DateTimeAxis(
                  minimum: latestTimestamp
                      .subtract(Duration(hours: oldestEntry.abs().toInt())),
                  maximum: latestTimestamp.add(Duration(hours: 1)),
                  interval: (oldestEntry.abs() / 4).ceilToDouble(),
                  isVisible: false,
                ),
                primaryYAxis: NumericAxis(
                  minimum: minGreen,
                  maximum: maxGreen,
                  interval: (maxGreen ~/ 3).toDouble(),
                  majorGridLines: MajorGridLines(width: 0),
                  isVisible: false,
                ),
                tooltipBehavior: TooltipBehavior(enable: false),
                enableSideBySideSeriesPlacement: false,
                enableAxisAnimation: true,
                series: [
                  ColumnSeries<_ChartData, DateTime>(
                    dataSource: dataGreen,
                    xValueMapper: (_ChartData sales, _) => sales.x,
                    yValueMapper: (_ChartData sales, _) => sales.y,
                    name: "stats label allowed".i18n,
                    color: colorsGreen[0],
                    animationDuration: 1000,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4)),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colorsGreen,
                        stops: stops),
                  ),
                ],
              )),
        ],
      );
    });
  }
}

class _ChartData {
  _ChartData(this.x, this.y);

  final DateTime x;
  final int y;
}
