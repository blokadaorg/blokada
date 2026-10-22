import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/placeholder.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(WidgetTester tester, Widget child, {bool reduceMotion = false}) => MaterialApp(
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
        accent: Colors.orange,
        freemium: Colors.orange,
        shadow: Colors.black,
        bgMiniCard: Colors.black,
        textPrimary: Colors.white,
        textSecondary: Colors.white70,
        divider: Colors.grey,
      ),
    ],
  ),
  home: MediaQuery(
    data: MediaQueryData.fromView(tester.view).copyWith(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('shimmers while shown', (tester) async {
    await tester.pumpWidget(_wrap(tester, LoadingPlaceholder.rows(count: 3, dividerIndent: 44)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.hasRunningAnimations, isTrue);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(PlaceholderBar), findsNWidgets(6));
  });

  testWidgets('with Reduce Motion, static grey and no animation', (tester) async {
    await tester.pumpWidget(_wrap(tester, LoadingPlaceholder.rows(count: 3), reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(PlaceholderBar), findsNWidgets(6));
  });

  testWidgets('stays still when not animated, and starts when it is', (tester) async {
    Widget placeholder(bool animate) =>
        _wrap(tester, LoadingPlaceholder(animate: animate, child: const PlaceholderBar()));

    await tester.pumpWidget(placeholder(false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(placeholder(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('tells screen readers it is loading, not the shapes', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(tester, LoadingPlaceholder.rows(count: 2)));

    expect(find.bySemanticsLabel("universal status loading".i18n), findsOneWidget);
    handle.dispose();
  });
}
