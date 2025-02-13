import 'package:common/common/navigation.dart';
import 'package:common/common/widget/app.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/modules.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/v6/widget/main_screen.dart';
import 'package:flutter/material.dart';

import 'platform/command/channel.pg.dart';
import 'platform/command/command.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const flavor = Flavor.v6;
  final modules = Modules();
  await modules.create(
      ActScreenplay(ActScenario.platformIsMocked, flavor, PlatformType.iOS));
  modules.start(Markers.start);

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

// In mocked, manually trigger the foreground
class MockedStart with Logging {
  late final StageStore _stage = Core.get<StageStore>();

  Future<void> start() async {
    await _stage.setForeground(Markers.start);
  }
}
