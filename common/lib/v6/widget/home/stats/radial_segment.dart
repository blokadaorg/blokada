import 'dart:math';

import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:common/util/color_extensions.dart';
import 'package:common/util/mobx.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'radial_chart.dart';

class RadialSegment extends StatefulWidget {
  final bool autoRefresh;

  const RadialSegment({Key? key, required this.autoRefresh}) : super(key: key);

  @override
  State<StatefulWidget> createState() => RadialSegmentState();
}

class RadialSegmentState extends State<RadialSegment> {
  final _store = DI.get<StatsStore>();

  //var stats = MockUiStats().defaults();
  var stats = UiStats.empty();
  var blocked = 0.0;
  var allowed = 0.0;
  var total = 0.0;
  var lastBlocked = 0.0;
  var lastAllowed = 0.0;
  var lastTotal = 0.0;

  @override
  void initState() {
    super.initState();
    setState(() {
      //stats = _store.statsForSelectedDevice();
    });

    if (widget.autoRefresh) {
      reactionOnStore((_) => _store.deviceStatsChangesCounter, (_) async {
        if (!mounted) return;
        setState(() {
          //stats = _store.statsForSelectedDevice();

          lastAllowed = allowed;
          lastBlocked = blocked;
          lastTotal = total;
          allowed = stats.dayAllowed.toDouble();
          blocked = stats.dayBlocked.toDouble();
          total = stats.dayTotal.toDouble();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              // Padding(
              //   padding: const EdgeInsets.all(4.0),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text("stats label blocked".i18n,
              //           maxLines: 1,
              //           style: const TextStyle(
              //             color: Color(0xffff3b30),
              //             fontSize: 12,
              //             fontWeight: FontWeight.w600,
              //           )),
              //       Countup(
              //         begin: lastBlocked,
              //         end: blocked,
              //         duration: const Duration(seconds: 1),
              //         style: const TextStyle(
              //           fontSize: 20,
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              // Padding(
              //   padding: const EdgeInsets.only(top: 4.0),
              //   child: SizedBox(
              //     height: 44,
              //     child: VerticalDivider(
              //       color: theme.divider,
              //       thickness: 1.0,
              //     ),
              //   ),
              // ),
              // Padding(
              //   padding: const EdgeInsets.all(4.0),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text("stats label allowed".i18n,
              //           maxLines: 1,
              //           style: const TextStyle(
              //             color: Color(0xff33c75a),
              //             fontSize: 14,
              //             fontWeight: FontWeight.w600,
              //           )),
              //       Countup(
              //         begin: lastAllowed,
              //         end: allowed,
              //         duration: const Duration(seconds: 1),
              //         style: const TextStyle(
              //           fontSize: 20,
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              _ColumnChart(stats: stats),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 96,
            height: 96,
            child: RadialChart(stats: stats),
          ),
        ]);
  }
}

String _formatCounter(int counter) {
  if (counter >= 1000000) {
    return "${(counter / 1000000.0).toStringAsFixed(2)}M";
    //} else if (counter >= 1000) {
    //  return "${(counter / 1000.0).toStringAsFixed(1)}K";
  } else {
    return "$counter";
  }
}

class _ColumnChart extends StatelessWidget {
  final UiStats stats;

  _ColumnChart({
    Key? key,
    required this.stats,
  }) : super(key: key) {
    _compute();
  }

  late List<_ChartData> dataGreen;
  late List<_ChartData> dataRed;
  late double minGreen;
  late double maxGreen;
  late double oldestEntry;
  late DateTime latestTimestamp;

  List<Color> colorsGreen = <Color>[
    Color(0xff33c75a),
    Color(0xff33c75a).darken(20),
  ];

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

    dataRed = stats.blockedHistogram
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 90, maxWidth: 220),
          child: SfCartesianChart(
            margin: const EdgeInsets.all(0),
            plotAreaBorderWidth: 0,
            primaryXAxis: DateTimeAxis(
              minimum: latestTimestamp
                  .subtract(Duration(hours: oldestEntry.abs().toInt())),
              maximum: latestTimestamp.add(const Duration(hours: 1)),
              interval: (oldestEntry.abs() / 4).ceilToDouble(),
              isVisible: false,
            ),
            primaryYAxis: NumericAxis(
              minimum: minGreen - 50,
              maximum: maxGreen,
              interval: (maxGreen ~/ 3).toDouble(),
              majorGridLines: const MajorGridLines(width: 0),
              isVisible: false,
            ),
            tooltipBehavior: TooltipBehavior(enable: false),
            enableSideBySideSeriesPlacement: false,
            enableAxisAnimation: true,
            series: [
              // SplineSeries<_ChartData, DateTime>(
              //   dataSource: dataGreen,
              //   xValueMapper: (_ChartData data, _) => data.x,
              //   yValueMapper: (_ChartData data, _) => data.y,
              //   color: Color(0xff33c75a),
              //   width: 3, // Line width
              // ),
              // SplineSeries<_ChartData, DateTime>(
              //   dataSource: dataRed,
              //   xValueMapper: (_ChartData data, _) => data.x,
              //   yValueMapper: (_ChartData data, _) => data.y,
              //   color: Color(0xffff3b30),
              //   width: 3, // Line width
              // ),
              ColumnSeries<_ChartData, DateTime>(
                dataSource: dataGreen,
                xValueMapper: (_ChartData sales, _) => sales.x,
                yValueMapper: (_ChartData sales, _) => sales.y,
                name: "stats label allowed".i18n,
                color: colorsGreen[0],
                width: 0.8,
                animationDuration: 1000,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colorsGreen,
                    stops: stops),
              ),
            ],
          ),
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
