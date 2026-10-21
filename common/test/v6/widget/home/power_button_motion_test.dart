import 'dart:async';

import 'package:common/src/app_variants/v6/widget/home/power_button.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/home/domain/power.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/touch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/fixtures.dart';
import '../../../golden/golden_tools.dart';

class _FakePowerActor extends Fake implements PowerActor {
  final confirmed = StreamController<void>.broadcast();

  int toggles = 0;

  @override
  Stream<void> get onProtectionConfirmed => confirmed.stream;

  @override
  Future<void> toggle(Marker m) async => toggles++;
}

PowerButtonPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(PowerButton), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as PowerButtonPainter;
}

Future<(_FakePowerActor, List<String>)> _pump(
  WidgetTester tester, {
  required AppStatus status,
  bool reduceMotion = false,
}) async {
  await bootModules(tester);
  await seedCloudAccount(tester);
  final power = _FakePowerActor();
  Core.di.allowReassignment = true;
  try {
    Core.register<PowerActor>(power);
  } finally {
    Core.di.allowReassignment = false;
  }
  seedAppStatus(status);

  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) {
    if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(disableAnimations: reduceMotion),
      child: BlokadaApp(
        isFamily: false,
        content: Scaffold(body: Center(child: PowerButton())),
      ),
    ),
  );
  // The button applies status changes after a 200 ms debounce; the next frame
  // starts the ring.
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
  return (power, haptics);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 10));
}

void main() {
  testWidgets('a tap thumps, the ring ticks as it winds up, then a rising run', (tester) async {
    final (power, haptics) = await _pump(tester, status: AppStatus.deactivated);

    await tester.tap(find.descendant(of: find.byType(PowerButton), matching: find.byType(Touch)));
    await tester.pump();
    expect(power.toggles, 1);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    haptics.clear();

    seedAppStatus(AppStatus.activatedCloud);
    await tester.pump(const Duration(milliseconds: 250));
    power.confirmed.add(null);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);

    await _unmount(tester);
  });

  testWidgets('the ring draws round, then pulses once with the success haptic', (tester) async {
    final (power, haptics) = await _pump(tester, status: AppStatus.activatedCloud);

    // Mid-draw: the ring is partway round and no pulse yet.
    await tester.pump(const Duration(milliseconds: 200));
    expect(_painter(tester).alphaLibre, inExclusiveRange(0.0, 1.0));
    expect(_painter(tester).sweepRings, isTrue);

    power.confirmed.add(null);
    await tester.pump();
    expect(_painter(tester).pulse, isNull, reason: 'the pulse waits for the ring to close');
    expect(haptics, isEmpty);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painter(tester).pulse, isNotNull);
    expect(haptics, isNotEmpty);

    await tester.pump(const Duration(seconds: 1));
    expect(_painter(tester).pulse, isNull);

    await _unmount(tester);
  });

  testWidgets('no pulse when Home opens with protection already on', (tester) async {
    final (_, haptics) = await _pump(tester, status: AppStatus.activatedCloud);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painter(tester).pulse, isNull);
    }
    expect(haptics, isEmpty);

    await _unmount(tester);
  });

  testWidgets('with Reduce Motion the ring fades and only the haptic plays', (tester) async {
    final (power, haptics) = await _pump(
      tester,
      status: AppStatus.activatedCloud,
      reduceMotion: true,
    );
    expect(_painter(tester).sweepRings, isFalse);

    power.confirmed.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(haptics, isNotEmpty);

    await tester.pump(const Duration(seconds: 1));
    expect(_painter(tester).pulse, isNull);

    await _unmount(tester);
  });
}
