import 'dart:async';
import 'dart:typed_data';

import 'package:common/model/UiModel.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class RadialChart extends StatelessWidget {

  final UiStats stats;

  RadialChart({Key? key, required this.stats}) : super(key: key) {
    _convert();
  }

  late List<_ChartData> data;
  CircularSeriesController? _chartSeriesController;

  List<Color> colors = <Color>[
    const Color(0xffff9400),
    const Color(0xffef6049)
  ];

  List<double> stops = <double>[
    0.1,
    0.7,
  ];

  void _convert() {
    data = [
      _ChartData('All', (stats.hourlyBlocked + stats.hourlyAllowed) / 10.0, const Color(0xff808080)),
      _ChartData('Allowed', stats.hourlyAllowed / 10.0, const Color(0xff33c75a)),
      _ChartData('Blocked', stats.hourlyBlocked / 1.0, const Color(0xffff3b30)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: SfCircularChart(
          // onCreateShader: (ChartShaderDetails chartShaderDetails) {
          //   return SweepGradient(
          //       center: Alignment.center,
          //       colors: colors,
          //       stops: stops,
          //       startAngle: _degreeToRadian(0),
          //       endAngle: _degreeToRadian(360),
          //       transform: GradientRotation(_degreeToRadian(-90))
          //   ).createShader(chartShaderDetails.outerRect);
          // },
          series: <CircularSeries>[
            // Renders radial bar chart
            RadialBarSeries<_ChartData, String>(
              dataSource: data,
              maximumValue: 1000,
              xValueMapper: (_ChartData data, _) => data.x,
              yValueMapper: (_ChartData data, _) => data.y,
              pointColorMapper: (_ChartData data, _) => data.color,
              cornerStyle: CornerStyle.bothCurve,
              useSeriesColor: true,
              trackOpacity: 0.1,
              innerRadius: '30%'
            )
          ]
        )
    );
  }

}


// Convert degree to radian
double _degreeToRadian(int deg) => deg * (3.141592653589793 / 180);


class _ChartData {
  _ChartData(this.x, this.y, this.color);

  final String x;
  final double y;
  final Color color;
}
