import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/stats_filter.dart';
import 'package:common/src/features/stats/ui/stats_filter_device.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/golden_tools.dart';

void main() {
  testWidgets('the open picker shows devices that load after it opened', (tester) async {
    await bootModules(tester);
    final devices = Core.get<JournalDevicesValue>();
    devices.now = {"Example Phone"};
    await tester.pumpWidget(
      BlokadaApp(
        isFamily: false,
        content: Scaffold(body: StatsDeviceFilter(filter: StatsFilterController())),
      ),
    );
    await tester.pump();
    expect(find.text("Example Phone"), findsOneWidget);
    expect(find.text("Example Router"), findsNothing);

    devices.now = {"Example Phone", "Example Router"};
    await tester.pump();
    await tester.pump();
    expect(find.text("Example Router"), findsOneWidget);
  });
}
