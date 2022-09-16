import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class RadialChart extends StatefulWidget {
  final int blocked;
  final int allowed;

  const RadialChart({Key? key,
    required this.blocked, required this.allowed
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => RadialChartState();
}

class RadialChartState extends State<RadialChart> {
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

  @override
  void initState() {
    data = [
      _ChartData('All', (widget.blocked + widget.allowed) / 1.0, const Color(0xff808080)),
      _ChartData('Allowed', widget.allowed / 1.0, const Color(0xff33c75a)),
      _ChartData('Blocked', widget.blocked / 1.0, const Color(0xffff3b30)),
    ];
    super.initState();
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
              maximumValue: widget.blocked * 5,
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
