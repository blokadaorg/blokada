import 'package:common/main_mocked_shared.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/widget/main_screen.dart';
import 'package:common/modules.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:flutter/material.dart';

import 'package:common/src/platform/command/channel.pg.dart';
import 'package:common/src/platform/command/command.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const flavor = Flavor.family;
  final modules = Modules();
  await modules.create(ActScreenplay(ActScenario.platformIsMocked, flavor, PlatformType.iOS));

  // Mirror the family-flavor base-URL switch from main.dart so API calls land
  // on family.api.blocka.net, not the default api.blocka.net.
  jsonUrl = "https://family.api.blocka.net";

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
    content: FamilyMainScreen(ctrl: ctrl, nav: nav),
    isFamily: true,
  ));

  MockedStart().start();
}
