import 'package:common/main_mocked_shared.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/modules.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:common/src/app_variants/v6/widget/main_screen.dart';
import 'package:flutter/material.dart';

import 'package:common/src/platform/command/channel.pg.dart';
import 'package:common/src/platform/command/command.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const flavor = Flavor.v6;
  final modules = Modules();
  await modules.create(ActScreenplay(ActScenario.platformIsMocked, flavor, PlatformType.iOS));

  await seedDevAccount(flavor);

  await modules.start(
    Markers.start,
    launchContext: AppLaunchContext.foregroundInteractive,
  );
  await modules.startForeground(Markers.start);

  final CommandStore command = Core.get<CommandStore>();
  command.onCommandWithParam(CommandName.route.name, "home", Markers.start);

  final ctrl = Core.get<TopBarController>();
  final nav = NavigationPopObserver();

  runApp(BlokadaApp(
    content: V6MainScreen(ctrl: ctrl, nav: nav),
    isFamily: false,
  ));

  MockedStart().start();
}
