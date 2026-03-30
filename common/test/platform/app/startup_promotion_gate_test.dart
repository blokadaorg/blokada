import 'dart:async';

import 'package:common/src/platform/app/launch_context.dart';
import 'package:common/src/platform/app/startup_promotion_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartupPromotionGate', () {
    testWidgets('background launch does not repromote while startForeground is in flight',
        (tester) async {
      final completer = Completer<void>();
      var startCalls = 0;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StartupPromotionGate(
              launchContext: const AppLaunchContext(
                reason: LaunchReason.backgroundTask,
                profile: BootstrapProfile.background,
              ),
              startForeground: (m) {
                startCalls += 1;
                return completer.future;
              },
              child: const Text('home')),
        ),
      );
      await tester.pump();

      expect(find.text('home'), findsOneWidget);
      expect(startCalls, 1);

      await tester.pump(const Duration(seconds: 2));
      expect(startCalls, 1);

      completer.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('background launch only promotes once after a successful promotion',
        (tester) async {
      var startCalls = 0;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StartupPromotionGate(
              launchContext: const AppLaunchContext(
                reason: LaunchReason.backgroundTask,
                profile: BootstrapProfile.background,
              ),
              startForeground: (m) async {
                startCalls += 1;
              },
              child: const Text('home')),
        ),
      );
      await tester.pump();

      expect(startCalls, 1);
      expect(find.text('home'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));

      expect(startCalls, 1);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('foreground launch renders child immediately', (tester) async {
      final completer = Completer<void>();
      var startCalls = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StartupPromotionGate(
              launchContext: AppLaunchContext.foregroundInteractive,
              startForeground: (m) async {
                startCalls += 1;
                await completer.future;
              },
              child: const Text('home')),
        ),
      );

      expect(find.text('home'), findsOneWidget);

      await tester.pump();

      expect(find.text('home'), findsOneWidget);
      expect(startCalls, 1);

      completer.complete();
      await tester.pump();
    });
  });
}
