import 'dart:io';
import 'dart:ui' as ui;

import 'package:common/src/app_variants/v6/module/home/home.dart';
import 'package:common/src/app_variants/v6/widget/home/trial_line.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/fixtures.dart';
import '../../../golden/golden_tools.dart';

class _FakeTrialHome extends TrialHomeActor {
  @override
  Future<void> refreshTrial(Marker m) async {}

  @override
  Future<void> refreshTrialBlocked(Marker m) async {}
}

/// iPhone SE (3rd generation): 375x667 pt at 2x.
const _seSize = Size(750, 1334);

/// Set to a directory to save a PNG of each case for a visual check.
final _shotsDir = Platform.environment['HOME_TRIAL_SHOTS'];

void main() {
  // Home with the trial line on the smallest supported iPhone, in German,
  // from default text up to the largest accessibility size (#460: Home must
  // not get crowded off screen).
  for (final scale in [1.0, 1.35, 2.0, 3.1]) {
    testWidgets('Home with the trial line fits an iPhone SE in German at text x$scale', (
      tester,
    ) async {
      await bootModules(tester, platform: PlatformType.iOS);
      await seedCloudAccount(tester);
      seedDevice();
      seedStats();
      seedAppStatus(AppStatus.activatedCloud);
      final actor = _FakeTrialHome();
      Core.di.allowReassignment = true;
      Core.register<TrialHomeActor>(actor);
      Core.di.allowReassignment = false;
      final today = DateTime.now();
      actor.trial.now = TrialProgress(
        length: 7,
        startedAt: DateTime(today.year, today.month, today.day - 2, 12),
      );
      actor.trialBlocked.now = 12345;

      tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pumpShell(
        tester,
        platform: TargetPlatform.iOS,
        physicalSize: _seSize,
        devicePixelRatio: 2,
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TrialLine), findsOneWidget);
      expect(find.textContaining('Tag 3 von 7'), findsOneWidget);

      if (_shotsDir != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$_shotsDir/home_trial_se_de_x$scale.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      debugDefaultTargetPlatformOverride = null;
      await unmountShell(tester);
    });
  }
}
