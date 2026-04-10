import 'dart:io' as io;

import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/widget/main_screen.dart';
import 'package:common/modules.dart';
import 'package:common/src/app_variants/v6/widget/main_screen.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:common/src/platform/app/startup_first_frame_reporter.dart';
import 'package:common/src/platform/app/startup_promotion_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

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

Widget _buildHome(Flavor flavor) {
  final ctrl = Core.get<TopBarController>();
  final nav = NavigationPopObserver();

  return (flavor == Flavor.family)
      ? FamilyMainScreen(ctrl: ctrl, nav: nav)
      : V6MainScreen(ctrl: ctrl, nav: nav);
}
