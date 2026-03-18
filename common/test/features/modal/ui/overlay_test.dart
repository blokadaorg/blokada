import 'package:common/src/core/core.dart';
import 'package:common/src/features/modal/ui/overlay.dart';
import 'package:common/src/features/onboard/domain/onboard.dart';
import 'package:common/src/features/onboard/ui/onboard_screen.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

void main() {
  testWidgets('shows onboarding overlay when modal is already set before mount',
      (tester) async {
    await withTrace((_) async {
      final stage = StageStore();
      stage.route = stage.route.newModal(StageModal.onboarding);

      Core.register<StageStore>(stage);
      Core.register<OnboardActor>(OnboardActor());

      await tester.pumpWidget(
        MaterialApp(
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
          home: Scaffold(
            body: Stack(
              children: const [
                Text('home'),
                OverlaySheet(),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
