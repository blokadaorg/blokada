import 'package:common/src/core/core.dart';
import 'package:common/src/features/toast/domain/toast.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools.dart';

/// WCAG 2 contrast ratio.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Body text needs 4.5:1 (WCAG AA).
const _aa = 4.5;

Future<BlokadaTheme> _themeOf(WidgetTester tester, Brightness brightness) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  late BlokadaTheme theme;
  await tester.pumpWidget(BlokadaApp(
    isFamily: Core.act.isFamily,
    content: Builder(builder: (context) {
      theme = context.theme;
      return const SizedBox();
    }),
  ));
  return theme;
}

void main() {
  for (final flavor in [Flavor.v6, Flavor.family]) {
    for (final brightness in Brightness.values) {
      testWidgets('${flavor.name} ${brightness.name} text tokens reach 4.5:1', (tester) async {
        await withTrace((m) async {
          Core.act = ActScreenplay(ActScenario.test, flavor, PlatformType.iOS);
          Core.register<ToastValue>(ToastValue());
          final t = await _themeOf(tester, brightness);

          expect(_contrast(t.onAccent, t.accent), greaterThanOrEqualTo(_aa),
              reason: 'text on accent buttons');
          for (final bg in [t.bgColor, t.bgColorCard]) {
            expect(_contrast(t.link, bg), greaterThanOrEqualTo(_aa), reason: 'links');
            expect(_contrast(t.textSecondary, bg), greaterThanOrEqualTo(_aa),
                reason: 'secondary text, e.g. blocklist tags');
          }
          for (final bg in [t.bgColor, t.bgColorCard, t.bgMiniCard]) {
            expect(_contrast(t.textBlocked, bg), greaterThanOrEqualTo(_aa), reason: 'blocked');
            expect(_contrast(t.textAllowed, bg), greaterThanOrEqualTo(_aa), reason: 'allowed');
          }
          // Links that are not in the accent color say so with an underline.
          if (t.link != t.accent) expect(t.linkUnderline, t.accent);
        });
      });
    }
  }
}
