import 'package:common/dragon/widget/app.dart';
import 'package:common/logger/logger.dart';
import 'package:common/mocked-deps.dart';
import 'package:common/stage/stage.dart';
import 'package:flutter/material.dart';

import 'command/channel.pg.dart';
import 'command/command.dart';
import 'common/i18n.dart';
import 'entrypoint.dart';
import 'ui/notfamily/scaffolding.dart';
import 'util/act.dart';
import 'util/di.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const flavor = Flavor.family;
  final entrypoint = Entrypoint();
  entrypoint.attach(
      ActScreenplay(ActScenario.platformIsMocked, flavor, Platform.ios));
  entrypoint.onStartApp();
  attachMockedDeps();

  final CommandStore command = dep<CommandStore>();
  command.onCommandWithParam(CommandName.route.name, "home", Markers.start);

  runApp(BlokadaApp(
    content: (flavor == Flavor.family) ? null : Scaffolding(title: 'Blokada'),
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
