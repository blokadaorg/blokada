import 'package:common/src/app_variants/v6/widget/home/power_button.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/fixtures.dart';
import '../../../golden/golden_tools.dart';

Future<void> _pump(WidgetTester tester, AppStatus status) async {
  await bootModules(tester);
  await seedCloudAccount(tester);
  seedAppStatus(status);
  await tester.pumpWidget(BlokadaApp(
    isFamily: false,
    content: Scaffold(body: Center(child: PowerButton())),
  ));
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 10));
}

void main() {
  // The label is for screen readers; the untranslated value stays because the
  // Appium flows read it (automation/appium/wdio/src/flows/home.ts).
  testWidgets('power button has a translated label and keeps its value', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, AppStatus.activatedCloud);

    final button = find.bySemanticsLabel("home power button label".i18n);
    expect(button, findsOneWidget);
    expect(
        tester.getSemantics(button),
        containsSemantics(
            isButton: true, value: 'active', hint: "home power button state on".i18n));

    seedAppStatus(AppStatus.deactivated);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getSemantics(button),
        containsSemantics(value: 'inactive', hint: "home power button state off".i18n));

    await _unmount(tester);
    handle.dispose();
  });
}
