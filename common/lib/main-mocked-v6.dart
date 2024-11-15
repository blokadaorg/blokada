import 'package:common/dragon/widget/app.dart';
import 'package:common/logger/logger.dart';
import 'package:common/stage/stage.dart';
import 'package:flutter/material.dart';

import 'command/channel.pg.dart';
import 'command/command.dart';
import 'common/i18n.dart';
import 'dragon/widget/v6/scaffolding.dart';
import 'entrypoint.dart';
import 'util/act.dart';
import 'util/di.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const flavor = Flavor.og;
  final entrypoint = Entrypoint();
  entrypoint.attach(
      ActScreenplay(ActScenario.platformIsMocked, flavor, Platform.ios));
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
