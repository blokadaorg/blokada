import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/stats_filter.dart';
import 'package:common/src/features/stats/ui/stats_filter_device.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/two_letter_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('a long device name starts after the badge and is ellipsized',
      (tester) async {
    await bootModules(tester);
    const name = "Google sdkgphone64arm64 with an even longer suffix";
    Core.get<JournalDevicesValue>().now = {name};
    await tester.pumpWidget(
      BlokadaApp(
        isFamily: false,
        content: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: StatsDeviceFilter(filter: StatsFilterController()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final badge = tester.getRect(find.byType(TwoLetterIconWidget));
    final text = tester.getRect(find.text(name));
    expect(text.left, greaterThan(badge.right));
    final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
    expect(paragraph.didExceedMaxLines, isTrue);
    expect(paragraph.size.height, lessThan(30));
  });
}
