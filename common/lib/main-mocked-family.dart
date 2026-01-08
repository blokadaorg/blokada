import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/widget/main_screen.dart';
import 'package:common/mocked-deps.dart';
import 'package:common/modules.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter/material.dart';

import 'package:common/src/platform/command/channel.pg.dart';
import 'package:common/src/platform/command/command.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const flavor = Flavor.family;
  final modules = Modules();
  await modules.create(
      ActScreenplay(ActScenario.platformIsMocked, flavor, PlatformType.iOS));
  attachMockedDeps();
  modules.start(Markers.start);

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

// In mocked, manually trigger the foreground
class MockedStart {
  late final StageStore _stage = Core.get<StageStore>();

  Future<void> start() async {
    await _stage.setForeground(Markers.start);
  }
}
