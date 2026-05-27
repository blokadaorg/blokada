import 'dart:io' as io;

import 'package:common/main_mocked_shared.dart';
import 'package:common/modules.dart';
import 'package:common/src/app_variants/family/widget/main_screen.dart';
import 'package:common/src/app_variants/v6/widget/main_screen.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:common/src/platform/app/startup_first_frame_reporter.dart';
import 'package:common/src/platform/app/startup_promotion_gate.dart';
import 'package:common/src/platform/command/channel.pg.dart';
import 'package:common/src/platform/command/command.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Mocked simulator builds set these via the DART_DEFINES env var that the iOS
// make layer (ios/make/sim-helpers.mk) supplies to xcodebuild. Shipping builds
// leave MOCKED unset, so _isMocked is a compile-time const false and the entire
// mocked branch (plus seedDevAccount / MockedStart) is dead-code-eliminated from
// release AOT binaries. This lets the Xcode build phase stay at Flutter's
// default, with no per-target FLUTTER_TARGET override for pod install to
// clobber. See ios/SIMULATOR.md.
const _isMocked = bool.fromEnvironment('MOCKED');
const _mockedFlavor = String.fromEnvironment('FLAVOR');

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  if (_isMocked) {
    await _startMocked();
  } else {
    await _startProd();
  }
}

Future<void> _startProd() async {
  const channel = MethodChannel('org.blokada/flavor');

  final Flavor flavor =
      await channel.invokeMethod('getFlavor') == "family" ? Flavor.family : Flavor.v6;

  final PlatformType platform = io.Platform.isAndroid ? PlatformType.android : PlatformType.iOS;
  final launchContext = await AppLaunchContext.load(Markers.start);

  final modules = Modules();
  if (kReleaseMode) {
    await modules.create(ActScreenplay(ActScenario.prod, flavor, platform));
  } else {
    await modules.create(ActScreenplay(ActScenario.prodWithToys, flavor, platform));
  }

  if (flavor == Flavor.family) {
    jsonUrl = "https://family.api.blocka.net";
  }

  await modules.start(Markers.start, launchContext: launchContext);

  // final ws = DevWebsocket();
  // depend(ws);
  // ws.handle();

  final home = _buildHome(flavor);

  runApp(
    BlokadaApp(
      content: StartupFirstFrameReporter(
        child: StartupPromotionGate(
          launchContext: launchContext,
          startForeground: modules.startForeground,
          child: home,
        ),
      ),
      isFamily: flavor == Flavor.family,
    ),
  );
}

// Mocked startup path, formerly the separate lib/main-mocked-{six,family}.dart
// entrypoints. Flavor comes from the FLAVOR dart-define (deterministic, no
// native dependency); a dev account is pre-seeded so the paywall and
// first-account flow are skipped; the production StartupPromotionGate is
// bypassed, so the foreground is triggered manually via MockedStart.
Future<void> _startMocked() async {
  final Flavor flavor = _mockedFlavor == "family" ? Flavor.family : Flavor.v6;

  final modules = Modules();
  await modules.create(ActScreenplay(ActScenario.platformIsMocked, flavor, PlatformType.iOS));

  if (flavor == Flavor.family) {
    jsonUrl = "https://family.api.blocka.net";
  }

  await seedDevAccount(flavor);

  await modules.start(
    Markers.start,
    launchContext: AppLaunchContext.foregroundInteractive,
  );
  await modules.startForeground(Markers.start);

  final CommandStore command = Core.get<CommandStore>();
  command.onCommandWithParam(CommandName.route.name, "home", Markers.start);

  runApp(BlokadaApp(
    content: _buildHome(flavor),
    isFamily: flavor == Flavor.family,
  ));

  MockedStart().start();

  startMockTraffic(flavor);
}

Widget _buildHome(Flavor flavor) {
  final ctrl = Core.get<TopBarController>();
  final nav = NavigationPopObserver();

  return (flavor == Flavor.family)
      ? FamilyMainScreen(ctrl: ctrl, nav: nav)
      : V6MainScreen(ctrl: ctrl, nav: nav);
}
