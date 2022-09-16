import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:common/model/UiModel.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ColumnChart extends StatefulWidget {

  final UiStats stats;

  ColumnChart({
    Key? key, required this.stats
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => ColumnChartState();

  }

class ColumnChartState extends State<ColumnChart> {

  late List<_ChartData> dataRed;
  late List<_ChartData> dataGreen;
  late double maxHour;
  late double minHour;
  late double oldestEntry;

  ChartSeriesController? _chartSeriesController;

  @override
  void initState() {
    _compute();
  }

  @override
  void didupdateWidget(ColumnChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _compute();
  }

  void _compute() {
    // data = [
    //   _ChartData('All', 30, const Color(0xff808080)),
    //   _ChartData('Allowed', 21, const Color(0xff33c75a)),
    //   _ChartData('Blocked', 9, const Color(0xffff3b30)),
    // ];
    dataRed = widget.stats.blockedHistogram.asMap().entries.map((entry) =>
        _ChartData(entry.key - 23, entry.value)
    ).toList();

    dataGreen = widget.stats.allowedHistogram.asMap().entries.map((entry) =>
        _ChartData(entry.key - 23, entry.value)
    ).toList();

    maxHour = 10; // Max Y axis value
    minHour = 1000;
    oldestEntry = -24; // Min X axis value
    for(var i = 0; i < 24; i++) {
      final hour = widget.stats.allowedHistogram[i] + widget.stats.blockedHistogram[i];
      if (hour > maxHour) maxHour = hour.toDouble();
      if (hour < minHour) minHour = max(0, hour * 0.8);
      // Skip consecutive zero bars at the beginning and shrink scale
      if (hour == 0 && oldestEntry.abs() == (24 - i) && oldestEntry < -6) oldestEntry += 1;
    }

  }




  List<Color> colors = <Color>[
    const Color(0xffA0A0A0),
    const Color(0xff808080)
  ];
  List<Color> colorsRed = <Color>[
    const Color(0xffff3b30),
    const Color(0xffa52018)
  ];

  List<Color> colorsGreen = <Color>[
    const Color(0xff33c75a),
    const Color(0xff138030)
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

    return Container(
        height: 200,
        child: SfCartesianChart(
            margin: EdgeInsets.all(0),
            plotAreaBorderWidth: 0,
            primaryXAxis: NumericAxis(
                minimum: oldestEntry, maximum: 1, interval: (oldestEntry.abs() / 2).ceilToDouble(),
                labelStyle: TextStyle(color: Color(0xff404040))
            ),
            primaryYAxis: CategoryAxis(
              minimum: minHour, maximum: maxHour, interval: (maxHour ~/ 3).toDouble(),
              majorGridLines: MajorGridLines(width: 0),
              opposedPosition: true,
              labelStyle: TextStyle(color: Color(0xff404040))
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: _getStackedColumnSeries(),
        )
    );
  }

  List<StackedColumnSeries<_ChartData, int>> _getStackedColumnSeries() {
    return <StackedColumnSeries<_ChartData, int>>[
      StackedColumnSeries<_ChartData, int>(
          dataSource: dataGreen,
          xValueMapper: (_ChartData sales, _) => sales.x,
          yValueMapper: (_ChartData sales, _) => sales.y,
          name: 'Allowed',
          color: colorsGreen[0],
          animationDuration: 500
          // gradient: LinearGradient(
          //     begin: Alignment.topCenter,
          //     end: Alignment.bottomCenter,
          //     colors: colorsGreen, stops: stops
          // ),
      ),
      StackedColumnSeries<_ChartData, int>(
          dataSource: dataRed,
          xValueMapper: (_ChartData sales, _) => sales.x,
          yValueMapper: (_ChartData sales, _) => sales.y,
          name: 'Blocked',
          borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
          color: colorsRed[0],
          animationDuration: 500
          // gradient: LinearGradient(
          //   begin: Alignment.topCenter,
          //   end: Alignment.bottomCenter,
          //   colors: colorsRed, stops: stops
          // ),
      ),
    ];
  }
}

class _ChartData {
  _ChartData(this.x, this.y);

  final int x;
  final int y;
}
