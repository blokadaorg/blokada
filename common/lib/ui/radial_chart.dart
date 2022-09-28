import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

  List<Color> colorsMixed = <Color>[
    const Color(0xffb6b6b6),
    const Color(0xff9f9f9f),
    const Color(0xff33c75a),
    const Color(0xff1cab42),
    const Color(0xffff3b30),
    const Color(0xffde342a),
  ];

  List<double> stopsMixed = <double>[
    0.35,
    0.52,
    0.56,
    0.76,
    0.80,
    0.90,
  ];

  List<Color> colorsRed = <Color>[
    const Color(0xffff3b30),
    const Color(0xffef6049)
  ];

  List<Color> colorsGreen = <Color>[
    const Color(0xff33c75a),
    const Color(0xff6de88d),
  ];

  List<Color> colorsGray = <Color>[
    const Color(0xff808080),
    const Color(0xffb6b6b6),
  ];

  List<double> stops = <double>[
    0.1,
    0.7,
  ];

  void _convert() {
    data = [
      _ChartData(
        'All',
        max((stats.rateTotal) / 1.0, 20),
        const Color(0xff808080),
        ui.Gradient.sweep(
          const Offset(0.5, 0.5),
          colorsGray,
          stops,
          TileMode.clamp,
          _degreeToRadian(0),
          _degreeToRadian(360),
        ),
      ),
      _ChartData(
        'Allowed',
        max(stats.rateAllowed / 1.0, 20),
        const Color(0xff33c75a),
        ui.Gradient.sweep(
          const Offset(0.5, 0.5),
          colorsGreen,
          stops,
          TileMode.clamp,
        ),
      ),
      _ChartData(
        'Blocked',
        max(stats.rateBlocked / 1.0, 20),
        const Color(0xffff3b30),
        ui.Gradient.sweep(
          const Offset(0.5, 0.5),
          colorsRed,
          stops,
          TileMode.clamp,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: SfCircularChart(
          onCreateShader: (ChartShaderDetails chartShaderDetails) {
            return RadialGradient(
                center: Alignment.center,
                colors: colorsMixed,
                stops: stopsMixed,
            ).createShader(chartShaderDetails.outerRect);
          },
          series: <CircularSeries>[
            // Renders radial bar chart
            RadialBarSeries<_ChartData, String>(
              dataSource: data,
              maximumValue: stats.avgTotal.toDouble(),
              xValueMapper: (_ChartData data, _) => data.x,
              yValueMapper: (_ChartData data, _) => data.y,
              pointColorMapper: (_ChartData data, _) => data.color,
              //pointShaderMapper: (_ChartData data, _, Color color, Rect rect) => data.shader,
              cornerStyle: CornerStyle.bothFlat,
              useSeriesColor: true,
              trackOpacity: 0.1,
              gap: '3%',
              innerRadius: '30%',
              radius: '80%',
              animationDuration: 3700,
            )
          ]
        )
    );
  }

}


// Convert degree to radian
double _degreeToRadian(int deg) => deg * (3.141592653589793 / 180);

// Rotate the sweep gradient according to the start angle
Float64List _resolveTransform(Rect bounds, TextDirection textDirection) {
  final GradientTransform transform = GradientRotation(_degreeToRadian(-90));
  return transform.transform(bounds, textDirection: textDirection)!.storage;
}

class _ChartData {
  _ChartData(this.x, this.y, this.color, this.shader);

  final String x;
  final double y;
  final Color color;
  final Shader shader;
}
