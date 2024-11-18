import 'package:common/core/core.dart';
import 'package:common/dragon/app.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/material.dart';

import 'entrypoint.dart';
import 'platform/command/channel.pg.dart';
import 'platform/command/command.dart';
import 'v6/widget/scaffolding.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const flavor = Flavor.v6;
  final entrypoint = Entrypoint();
  entrypoint.onRegister(
      ActScreenplay(ActScenario.platformIsMocked, flavor, PlatformType.iOS));
  entrypoint.onStartApp();

  final CommandStore command = dep<CommandStore>();
  command.onCommandWithParam(CommandName.route.name, "home", Markers.start);

  runApp(BlokadaApp(
    content: const Scaffolding(title: 'Blokada'),
  ));

  MockedStart().start();
}

// In mocked, manually trigger the foreground
class MockedStart with Logging {
  late final StageStore _stage = dep<StageStore>();

  Future<void> start() async {
    await _stage.setForeground(Markers.start);
  }
}
