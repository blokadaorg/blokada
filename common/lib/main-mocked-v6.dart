import 'package:common/common/widget/app.dart';
import 'package:common/core/core.dart';
import 'package:common/modules.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/material.dart';

import 'platform/command/channel.pg.dart';
import 'platform/command/command.dart';
import 'v6/widget/scaffolding.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const flavor = Flavor.v6;
  final modules = Modules();
  await modules.create(
      ActScreenplay(ActScenario.platformIsMocked, flavor, PlatformType.iOS));
  modules.start(Markers.start);

  final CommandStore command = DI.get<CommandStore>();
  command.onCommandWithParam(CommandName.route.name, "home", Markers.start);

  runApp(BlokadaApp(
    content: const Scaffolding(title: 'Blokada'),
  ));

  MockedStart().start();
}

// In mocked, manually trigger the foreground
class MockedStart with Logging {
  late final StageStore _stage = DI.get<StageStore>();

  Future<void> start() async {
    await _stage.setForeground(Markers.start);
  }
}
