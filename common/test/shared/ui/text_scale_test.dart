import 'package:common/src/shared/ui/text_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = TextStyle(fontSize: 20);

  group('fitWords', () {
    test('leaves the scale alone when every word fits', () {
      const scaler = TextScaler.linear(3);
      expect(fitWords('Keine Werbung', style, scaler, 1000), same(scaler));
    });

    test('shrinks until the widest word fits the line', () {
      const scaler = TextScaler.linear(3);
      const word = 'Werbeblockierung';
      final fitted = fitWords(word, style, scaler, 600);
      final factor = fitted.scale(20) / 20;
      expect(factor, lessThan(3));
      expect(factor, greaterThanOrEqualTo(1));

      final painter = TextPainter(
        text: const TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: fitted,
      )..layout();
      expect(painter.width, lessThanOrEqualTo(600));
      painter.dispose();
    });

    test('never goes below the default size', () {
      const scaler = TextScaler.linear(2);
      final fitted = fitWords('Werbeblockierungsfunktionen', style, scaler, 20);
      expect(fitted.scale(20) / 20, 1);
    });

    test('treats a hyphen as a line break opportunity', () {
      const scaler = TextScaler.linear(3);
      // Each half fits on its own line; together they would not.
      final whole = fitWords('TrackingKontrolle', style, scaler, 300);
      final hyphenated = fitWords('Tracking-Kontrolle', style, scaler, 300);
      expect(hyphenated.scale(20), greaterThan(whole.scale(20)));
    });
  });

  testWidgets('WordFitText lays out under an intrinsic-size parent', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(3)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: IntrinsicHeight(
              child: SizedBox(width: 120, child: WordFitText('Werbeblockierung ist aktiv')),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Werbeblockierung ist aktiv'), findsOneWidget);
  });

  testWidgets('WordFitText takes taps for the GestureDetector around it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            onTap: () => taps++,
            child: const Padding(padding: EdgeInsets.all(8), child: WordFitText('Cancel')),
          ),
        ),
      ),
    );
    await tester.tapAt(tester.getCenter(find.byType(WordFitText)));
    expect(taps, 1);
  });
}
