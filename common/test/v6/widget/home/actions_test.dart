import 'dart:async';

import 'package:common/src/app_variants/v6/widget/home/actions.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/app/start/start.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/action_sheet.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:mocktail/mocktail.dart';

import '../../../golden/fixtures.dart';
import '../../../golden/golden_tools.dart';

final _pausedElsewhereText =
    "${"home status paused elsewhere".i18n} · ${"universal action resume".i18n}";

class _MockAppStartStore extends Mock implements AppStartStore {}

/// Replaces the real start store, so a tap is observed instead of running the
/// whole unpause flow against fake HTTP.
_MockAppStartStore _mockAppStart() {
  final appStart = _MockAppStartStore();
  when(() => appStart.pausedForAccurate).thenReturn(null);
  when(() => appStart.toggleApp(any(), duration: any(named: 'duration'))).thenAnswer((_) async {});
  Core.di.allowReassignment = true;
  try {
    Core.register<AppStartStore>(appStart);
  } finally {
    Core.di.allowReassignment = false;
  }
  return appStart;
}

Future<void> _pump(WidgetTester tester, {required bool? issuedHere}) async {
  await bootModules(tester);
  await seedCloudAccount(tester);
  seedAppStatus(AppStatus.deactivated);
  runInAction(() => Core.get<DeviceStore>().cloudEnabled = false);
  await tester.runAsync(() => Core.get<PauseIssuedHereValue>().change(Markers.testing, issuedHere));
  await tester.pumpWidget(
    BlokadaApp(
      isFamily: false,
      content: const Scaffold(body: Center(child: HomeActions())),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 10));
}

Finder _pausedElsewhereId() => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == AutomationIds.homePausedElsewhere,
);

void main() {
  setUpAll(() => registerFallbackValue(Markers.testing));

  group('HomeActions pause origin', () {
    testWidgets('a stored origin read late does not undo a newer change', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedAppStatus(AppStatus.deactivated);
      runInAction(() => Core.get<DeviceStore>().cloudEnabled = false);

      // The stored value loads slowly; meanwhile the account is seen paused
      // by another device.
      final stored = Completer<bool?>();
      final origin = PauseIssuedHereValue()
        ..load = ((_) => stored.future)
        ..save = ((_, _) async {});
      Core.di.allowReassignment = true;
      try {
        Core.register<PauseIssuedHereValue>(origin);
      } finally {
        Core.di.allowReassignment = false;
      }

      await tester.pumpWidget(
        BlokadaApp(
          isFamily: false,
          content: const Scaffold(body: Center(child: HomeActions())),
        ),
      );
      await tester.runAsync(() => origin.change(Markers.testing, false));
      await tester.pump();
      expect(find.text(_pausedElsewhereText), findsOneWidget);

      // The old stored value (our own pause) arrives after the change.
      stored.complete(true);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_pausedElsewhereText), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('a pause from another device says so and offers resume', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, issuedHere: false);
      // After boot, which registers the real store; HomeActions reads it on build.
      await tester.pumpWidget(const SizedBox());
      final appStart = _mockAppStart();
      await tester.pumpWidget(
        BlokadaApp(
          isFamily: false,
          content: const Scaffold(body: Center(child: HomeActions())),
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_pausedElsewhereText), findsOneWidget);
      expect(_pausedElsewhereId(), findsOneWidget);
      // A screen reader announces it as the resume button it is.
      expect(
        tester.getSemantics(find.text(_pausedElsewhereText)),
        containsSemantics(isButton: true),
      );

      await tester.tap(find.text(_pausedElsewhereText));
      await tester.pump();
      verify(() => appStart.toggleApp(any())).called(1);

      await _unmount(tester);
      handle.dispose();
    });

    testWidgets('our own pause keeps the plain off state', (tester) async {
      await _pump(tester, issuedHere: true);

      expect(find.text("home action tap to activate".i18n), findsOneWidget);
      expect(_pausedElsewhereId(), findsNothing);

      await _unmount(tester);
    });

    testWidgets('an unknown origin keeps the plain off state', (tester) async {
      await _pump(tester, issuedHere: null);

      expect(find.text("home action tap to activate".i18n), findsOneWidget);
      expect(_pausedElsewhereId(), findsNothing);

      await _unmount(tester);
    });

    testWidgets('origin learned later updates the text', (tester) async {
      await _pump(tester, issuedHere: null);
      expect(find.text(_pausedElsewhereText), findsNothing);

      await tester.runAsync(() => Core.get<PauseIssuedHereValue>().change(Markers.testing, false));
      await tester.pump();

      expect(find.text(_pausedElsewhereText), findsOneWidget);

      await _unmount(tester);
    });
  });

  testWidgets('the pause sheet says the pause covers every device', (tester) async {
    await bootModules(tester);
    await tester.pumpWidget(
      BlokadaApp(
        isFamily: false,
        content: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPauseActionSheet(context, onSelected: (_) {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text("home power pause scope".i18n), findsOneWidget);

    await _unmount(tester);
  });
}
