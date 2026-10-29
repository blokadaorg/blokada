import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/back_title_nav_bar.dart';
import 'package:common/src/shared/ui/nav_bar_button.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../tools.dart';

Widget _wrapOn(TargetPlatform platform, Widget child, {double textScale = 1.0}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
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
      home: Scaffold(body: child),
    );

Widget _commonBar(TargetPlatform platform) {
  final ctrl = TopBarController()
    ..nav = ['Home', 'Settings']
    ..show = 1.0;
  return _wrapOn(
    platform,
    ChangeNotifierProvider.value(value: ctrl, child: const TopCommonBar()),
  );
}

/// Space between the bottom of [bubble] and the bottom of [bar].
double _gapUnder(WidgetTester tester, Finder bubble, Finder bar) =>
    tester.getRect(bar).bottom - tester.getRect(bubble).bottom;

Decoration? _decorationAround(WidgetTester tester, Finder child) {
  final container = tester.widget<Container>(
      find.ancestor(of: child, matching: find.byType(Container)).first);
  return container.decoration;
}

void main() {
  group('TopCommonBar', () {
    testWidgets('iOS shows the chevron alone and names the destination for screen readers',
        (tester) async {
      await withTrace((_) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_commonBar(TargetPlatform.iOS));

        expect(find.text('Home'), findsNothing);
        expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(find.bySemanticsIdentifier(AutomationIds.navBack), findsOneWidget);
        expect(tester.getSemantics(find.byType(NavBarBackButton)),
            containsSemantics(value: 'Home', isButton: true, hasTapAction: true));
        semantics.dispose();
      });
    });

    testWidgets('Android shows its arrow and keeps the previous title label', (tester) async {
      await withTrace((_) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_commonBar(TargetPlatform.android));

        expect(find.text('Home'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
        expect(tester.getSemantics(find.bySemanticsIdentifier(AutomationIds.navBack)),
            containsSemantics(label: 'back', isButton: true, hasTapAction: true));
        semantics.dispose();
      });
    });
  });

  group('iOS bar bubbles', () {
    TopBarController ctrl() => TopBarController()
      ..nav = ['Home', 'Settings']
      ..show = 1.0;

    // 2.0 is past the bars' text clamp, so the largest bubbles they draw.
    for (final scale in [1.0, 2.0]) {
      testWidgets('back bubble keeps off the bottom edge at text scale $scale', (tester) async {
        await withTrace((_) async {
          await tester.pumpWidget(_wrapOn(
            TargetPlatform.iOS,
            textScale: scale,
            ChangeNotifierProvider.value(
              value: ctrl(),
              child: const Align(alignment: Alignment.topCenter, child: TopCommonBar()),
            ),
          ));

          expect(_gapUnder(tester, find.byType(NavBarBackButton), find.byType(TopCommonBar)),
              greaterThanOrEqualTo(6));
        });
      });

      testWidgets('trailing bubble keeps off the bottom edge and lines up with the title '
          'at text scale $scale', (tester) async {
        await withTrace((_) async {
          await tester.pumpWidget(_wrapOn(
            TargetPlatform.iOS,
            textScale: scale,
            ChangeNotifierProvider.value(
              value: ctrl(),
              child: Align(
                alignment: Alignment.topCenter,
                child: TopBar(
                  title: 'Settings',
                  trailing: NavBarButton(onTap: () {}, child: const Text('Add')),
                ),
              ),
            ),
          ));

          final bubble = find.byType(NavBarButton);
          expect(_gapUnder(tester, bubble, find.byType(TopBar)), greaterThanOrEqualTo(6));
          // The test font's line height differs from the system font's, so
          // allow a few points either way.
          expect(tester.getCenter(bubble).dy,
              moreOrLessEquals(tester.getCenter(find.text('Settings')).dy, epsilon: 4));
        });
      });
    }
  });

  group('BackTitleNavBar', () {
    Widget bar(TargetPlatform platform, VoidCallback onBack) => _wrapOn(
          platform,
          BackTitleNavBar(
            previousPageTitle: 'Kid phone',
            backKey: const Key('back'),
            onBackTap: onBack,
            title: const Text('Edit rule'),
          ),
        );

    testWidgets('iOS drops the back label but keeps the tap and the destination',
        (tester) async {
      await withTrace((_) async {
        final semantics = tester.ensureSemantics();
        var tapped = false;
        await tester.pumpWidget(bar(TargetPlatform.iOS, () => tapped = true));

        expect(find.text('Kid phone'), findsNothing);
        expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(tester.getSemantics(find.byKey(const Key('back'))),
            containsSemantics(value: 'Kid phone', isButton: true));
        await tester.tap(find.byKey(const Key('back')));
        // Let the press highlight reset before the tree is torn down.
        await tester.pump(const Duration(milliseconds: 200));
        expect(tapped, isTrue);
        semantics.dispose();
      });
    });

    testWidgets('Android shows its arrow and keeps the back label', (tester) async {
      await withTrace((_) async {
        var tapped = false;
        await tester.pumpWidget(bar(TargetPlatform.android, () => tapped = true));

        expect(find.text('Kid phone'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.chevron_back), findsNothing);
        await tester.tap(find.byKey(const Key('back')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tapped, isTrue);
      });
    });
  });

  group('NavBarButton', () {
    Widget button(TargetPlatform platform) =>
        _wrapOn(platform, Center(child: NavBarButton(onTap: () {}, child: const Text('Add'))));

    testWidgets('iOS draws a superellipse bubble', (tester) async {
      await withTrace((_) async {
        await tester.pumpWidget(button(TargetPlatform.iOS));

        final decoration = _decorationAround(tester, find.text('Add'));
        expect(decoration, isA<ShapeDecoration>());
        expect((decoration as ShapeDecoration).shape, isA<RoundedSuperellipseBorder>());
        expect(decoration.color, isNotNull);
      });
    });

    testWidgets('Android keeps the plain rounded press highlight', (tester) async {
      await withTrace((_) async {
        await tester.pumpWidget(button(TargetPlatform.android));

        final decoration = _decorationAround(tester, find.text('Add'));
        expect(decoration, isA<BoxDecoration>());
        expect((decoration as BoxDecoration).color, isNull);
      });
    });
  });
}
