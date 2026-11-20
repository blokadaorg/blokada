import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:common/src/features/home/ui/header/header_button.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(
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
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a labeled header button is one tappable node with the automation id', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        MergeSemantics(
          child: Semantics(
            identifier: AutomationIds.homeSettings,
            child: SmartHeaderButton(
              icon: CupertinoIcons.settings,
              label: 'Settings',
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('Settings'));
    final data = node.getSemanticsData();
    expect(data.identifier, AutomationIds.homeSettings);
    expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.tap);
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('an unlabeled header button adds no semantics of its own', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const SmartHeaderButton(icon: CupertinoIcons.settings)));
    expect(find.bySemanticsLabel('Settings'), findsNothing);
    handle.dispose();
  });
}
