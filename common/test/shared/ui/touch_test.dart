import 'package:common/src/shared/ui/touch.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

Touch _touch({bool shrink = true}) => Touch(
  onTap: () {},
  shrink: shrink,
  decorationBuilder: (value) => BoxDecoration(color: Colors.black.withOpacity(value)),
  child: const SizedBox(width: 100, height: 50),
);

double _scale(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(of: find.byType(Touch), matching: find.byType(Transform)).first,
  );
  return transform.transform.storage[0];
}

double _highlight(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(of: find.byType(Touch), matching: find.byType(Container)).first,
  );
  return (box.decoration as BoxDecoration).color!.a;
}

Future<TestGesture> _press(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byType(Touch)));
  // Tap down lands after the press timeout (the button also takes long
  // presses), then the press eases in over 100 ms.
  await tester.pump(kPressTimeout);
  await tester.pump(const Duration(milliseconds: 150));
  return gesture;
}

void main() {
  testWidgets('shrinks to 97% with a highlight while pressed, then springs back', (tester) async {
    await tester.pumpWidget(_wrap(_touch()));
    expect(_scale(tester), 1.0);

    final gesture = await _press(tester);
    expect(_scale(tester), closeTo(0.97, 0.001));
    expect(_highlight(tester), greaterThan(0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_scale(tester), 1.0);
    expect(_highlight(tester), 0);
  });

  testWidgets('highlights without shrinking when shrink is off', (tester) async {
    await tester.pumpWidget(_wrap(_touch(shrink: false)));
    final gesture = await _press(tester);
    expect(_scale(tester), 1.0);
    expect(_highlight(tester), greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('with Reduce Motion, highlight only', (tester) async {
    await tester.pumpWidget(_wrap(_touch(), reduceMotion: true));
    final gesture = await _press(tester);
    expect(_scale(tester), 1.0);
    expect(_highlight(tester), greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
