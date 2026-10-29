import 'package:common/src/core/core.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/modal/ui/bottom_sheet.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

const _lightTheme = BlokadaTheme(
  bgColor: Color(0xFFF2F1F6),
  bgColorHome1: Colors.white,
  bgColorHome2: Colors.white,
  bgColorHome3: Colors.white,
  bgColorCard: Colors.white,
  panelBackground: Colors.white,
  cloud: Color(0xFF007AFF),
  accent: Color(0xffe450ba),
  freemium: Color(0xFF48A9A6),
  shadow: Color(0xffe8e8e8),
  bgMiniCard: Colors.white,
  textPrimary: Colors.black,
  textSecondary: Colors.black54,
  divider: Colors.black26,
);

void main() {
  testWidgets("a sheet requested while the previous one is still closing is shown "
      "once that one is gone", (tester) async {
    await withTrace((m) async {
      final modal = CurrentModalValue();
      final modalWidget = CurrentModalWidgetValue();
      Core.register<CurrentModalValue>(modal);
      Core.register<CurrentModalWidgetValue>(modalWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [_lightTheme]),
          home: const Scaffold(body: BottomManagerSheet()),
        ),
      );

      await modal.change(m, Modal.pause);
      await modalWidget.change(m, (_) => const Text("first"));
      await tester.pumpAndSettle();
      expect(find.text("first"), findsOneWidget);

      // Dismissed from code, then the next sheet is requested straight away,
      // while the first one is still animating out.
      await modal.change(m, null);
      await modal.change(m, Modal.support);
      await modalWidget.change(m, (_) => const Text("second"));
      await tester.pumpAndSettle();

      expect(find.text("first"), findsNothing);
      expect(find.text("second"), findsOneWidget);
      expect(modal.present, Modal.support);
    });
  });

  testWidgets("closing the only sheet clears the modal", (tester) async {
    await withTrace((m) async {
      final modal = CurrentModalValue();
      final modalWidget = CurrentModalWidgetValue();
      Core.register<CurrentModalValue>(modal);
      Core.register<CurrentModalWidgetValue>(modalWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [_lightTheme]),
          home: const Scaffold(body: BottomManagerSheet()),
        ),
      );

      await modal.change(m, Modal.pause);
      await modalWidget.change(m, (_) => const Text("first"));
      await tester.pumpAndSettle();

      await modal.change(m, null);
      await tester.pumpAndSettle();

      expect(find.text("first"), findsNothing);
      expect(modal.present, isNull);
    });
  });
}
