import 'package:common/core/core.dart';
import 'package:common/dragon/app.dart';
import 'package:common/mocked-deps.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/material.dart';

import 'entrypoint.dart';
import 'platform/command/channel.pg.dart';
import 'platform/command/command.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const flavor = Flavor.family;
  final entrypoint = Entrypoint();
  entrypoint.attach(
      ActScreenplay(ActScenario.platformIsMocked, flavor, PlatformType.iOS));
  entrypoint.onStartApp();
  attachMockedDeps();

  final CommandStore command = dep<CommandStore>();
  command.onCommandWithParam(CommandName.route.name, "home", Markers.start);

  runApp(BlokadaApp(
    content: null,
  ));

  MockedStart().start();
}

// In mocked, manually trigger the foreground
class MockedStart {
  late final StageStore _stage = dep<StageStore>();

  Future<void> start() async {
    await _stage.setForeground(Markers.start);
  }
}
