import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ColumnChart extends StatefulWidget {
  final bool? red;
  final bool? green;

  const ColumnChart({Key? key, this.red, this.green}) : super(key: key);




  @override
  State<StatefulWidget> createState() => ColumnChartState();
}

class ColumnChartState extends State<ColumnChart> {
  late List<_ChartData> data;
  late List<_ChartData> dataRed;
  late List<_ChartData> dataGreen;

  ChartSeriesController? _chartSeriesController;


  @override
  void initState() {
    // data = [
    //   _ChartData('All', 30, const Color(0xff808080)),
    //   _ChartData('Allowed', 21, const Color(0xff33c75a)),
    //   _ChartData('Blocked', 9, const Color(0xffff3b30)),
    // ];
    data = [
      _ChartData(0, 0),
      _ChartData(1, 10),
      _ChartData(2, 0),
      _ChartData(3, 1),
      _ChartData(4, 0),
      _ChartData(5, 3),
      _ChartData(6, 5),
      _ChartData(7, 10),
      _ChartData(8, 20),
      _ChartData(9, 30),
      _ChartData(10, 40),
      _ChartData(11, 28),
      _ChartData(12, 0),
    ];
    dataRed = [
      _ChartData(0, 0),
      _ChartData(1, 4),
      _ChartData(2, 0),
      _ChartData(3, 1),
      _ChartData(4, 0),
      _ChartData(5, 2),
      _ChartData(6, 3),
      _ChartData(7, 6),
      _ChartData(8, 17),
      _ChartData(9, 20),
      _ChartData(10, 30),
      _ChartData(11, 18),
      _ChartData(12, 0),
    ];
    dataGreen = [
      _ChartData(0, 0),
      _ChartData(1, 6),
      _ChartData(2, 0),
      _ChartData(3, 0),
      _ChartData(4, 0),
      _ChartData(5, 1),
      _ChartData(6, 2),
      _ChartData(7, 4),
      _ChartData(8, 3),
      _ChartData(9, 10),
      _ChartData(10, 30),
      _ChartData(11, 10),
      _ChartData(12, 0),
    ];
    super.initState();
  }

  double _degreeToRadian(int deg) => deg * (3.141592653589793 / 180);



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


    LinearGradient gradientColors = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: widget.red == true ? colorsRed : (widget.green == true ? colorsGreen : colors), stops: stops
    );


    Timer(Duration(seconds: 5), () {
      _chartSeriesController?.animate();
    });

    return Container(
        height: 200,
        child: SfCartesianChart(
            margin: EdgeInsets.all(0),
            plotAreaBorderWidth: 0,
            primaryXAxis: NumericAxis(
                minimum: 0, maximum: 12, interval: 3,
                labelStyle: TextStyle(color: Color(0xff404040))
            ),
            primaryYAxis: CategoryAxis(
              minimum: 0, maximum: 60, interval: 100,
              majorGridLines: MajorGridLines(width: 0),
              opposedPosition: true,
              labelStyle: TextStyle(color: Color(0xff404040))
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: _getStackedColumnSeries()
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
          color: colorsGreen[0]
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
