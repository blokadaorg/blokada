import 'package:common/v6/widget/home/stats/radial_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gaugeFillFromDelta maps percent to 0-100 scale', () {
    final cases = <int, double>{
      -200: 0,
      -100: 0,
      -50: 25,
      0: 50,
      50: 75,
      100: 100,
      200: 100,
    };

    for (final entry in cases.entries) {
      expect(
        RadialChart.gaugeFillFromDelta(entry.key),
        closeTo(entry.value, 0.0001),
      );
    }
  });
}
