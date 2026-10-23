import 'package:common/src/core/core.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/action_sheet.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the pause sheet on [platform] and returns what the user picked:
/// a list that gets one entry per pick.
Future<List<Duration?>> _open(WidgetTester tester, TargetPlatform platform) async {
  final picked = <Duration?>[];
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
      platform: platform,
      extensions: const [
        BlokadaTheme(
          bgColor: Colors.black,
          bgColorHome1: Colors.black,
          bgColorHome2: Colors.black,
          bgColorHome3: Colors.black,
          bgColorCard: Colors.black,
          panelBackground: Colors.black,
          cloud: Colors.blue,
          accent: Colors.blue,
          freemium: Colors.orange,
          shadow: Colors.black,
          bgMiniCard: Colors.black,
          textPrimary: Colors.white,
          textSecondary: Colors.white70,
          divider: Colors.grey,
        ),
      ],
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showPauseActionSheet(context, onSelected: picked.add),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  const ids = [
    AutomationIds.powerActionSheet,
    AutomationIds.powerActionPauseFive,
    AutomationIds.powerActionTurnOff,
    AutomationIds.powerActionCancel,
  ];

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('pause sheet on ${platform.name}', () {
      testWidgets('is the platform sheet and keeps the automation ids', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, platform);

        final ios = platform == TargetPlatform.iOS;
        expect(find.byType(CupertinoActionSheet), ios ? findsOneWidget : findsNothing);
        expect(find.byType(BottomSheet), ios ? findsNothing : findsOneWidget);
        for (final id in ids) {
          expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
        }
        for (final id in ids.skip(1)) {
          expect(tester.getSemantics(find.bySemanticsIdentifier(id)),
              containsSemantics(isButton: true, hasTapAction: true),
              reason: id);
        }
        semantics.dispose();
      });

      testWidgets('pause picks five minutes and closes', (tester) async {
        final semantics = tester.ensureSemantics();
        final picked = await _open(tester, platform);

        await tester.tap(find.bySemanticsIdentifier(AutomationIds.powerActionPauseFive));
        await tester.pumpAndSettle();

        expect(picked, [const Duration(minutes: 5)]);
        expect(find.bySemanticsIdentifier(AutomationIds.powerActionSheet), findsNothing);
        semantics.dispose();
      });

      testWidgets('turn off picks no duration', (tester) async {
        final semantics = tester.ensureSemantics();
        final picked = await _open(tester, platform);

        await tester.tap(find.bySemanticsIdentifier(AutomationIds.powerActionTurnOff));
        await tester.pumpAndSettle();

        expect(picked, [null]);
        semantics.dispose();
      });

      testWidgets('cancel closes without a pick', (tester) async {
        final semantics = tester.ensureSemantics();
        final picked = await _open(tester, platform);

        await tester.tap(find.bySemanticsIdentifier(AutomationIds.powerActionCancel));
        await tester.pumpAndSettle();

        expect(picked, isEmpty);
        expect(find.bySemanticsIdentifier(AutomationIds.powerActionSheet), findsNothing);
        semantics.dispose();
      });
    });
  }

  testWidgets('on a short screen with large text the Android sheet scrolls to every action',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final picked = await _open(tester, TargetPlatform.android);
    expect(tester.takeException(), isNull);

    final cancel = find.text('universal action cancel'.i18n);
    await tester.scrollUntilVisible(cancel, 100, scrollable: find.byType(Scrollable).last);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
