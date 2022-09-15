import 'package:flutter/material.dart';

import 'samples/pie_chart_sample1.dart';
import 'samples/pie_chart_sample2.dart';
import 'samples/pie_chart_sample3.dart';

class PieChartPage extends StatelessWidget {

  const PieChartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: ListView(
          children: const <Widget>[
            SizedBox(
              height: 8,
            ),
            PieChartSample1(),
            SizedBox(
              height: 12,
            ),
            PieChartSample2(),
            SizedBox(
              height: 12,
            ),
            PieChartSample3(),
          ],
        ),
      ),
    );
  }
}
