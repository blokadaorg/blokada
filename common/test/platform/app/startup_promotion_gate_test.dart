import 'dart:async';

import 'package:common/src/platform/app/launch_context.dart';
import 'package:common/src/platform/app/startup_promotion_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartupPromotionGate', () {
    testWidgets('background launch shows placeholder until resumed promotion completes',
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

      expect(find.byKey(StartupPromotionGate.placeholderKey), findsOneWidget);
      expect(find.text('home'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(startCalls, 1);
      expect(find.byKey(StartupPromotionGate.placeholderKey), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(startCalls, 1);

      completer.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(StartupPromotionGate.placeholderKey), findsNothing);
      expect(find.text('home'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(startCalls, 1);
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
      expect(find.byKey(StartupPromotionGate.placeholderKey), findsNothing);

      await tester.pump();

      expect(find.text('home'), findsOneWidget);
      expect(find.byKey(StartupPromotionGate.placeholderKey), findsNothing);
      expect(startCalls, 1);

      completer.complete();
      await tester.pump();
    });
  });
}
