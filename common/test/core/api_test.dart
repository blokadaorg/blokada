import 'dart:convert';

import 'package:common/platform/stats/json.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  test("will decode json metrics", () async {
    const body = Fixtures.apiResponseMetrics;
    final data = json.decode(body);
    final metrics = JsonMetrics.fromJson(data);
    expect(metrics.tags!.action, "blocked");
    expect(metrics.dps![1].value, 2);
  });
}
