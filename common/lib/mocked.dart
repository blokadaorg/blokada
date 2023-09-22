import 'package:flutter/material.dart';

import 'command/channel.pg.dart';
import 'command/command.dart';
import 'entrypoint.dart';
import 'service/I18nService.dart';
import 'ui/root.dart';
import 'util/act.dart';
import 'util/di.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  final entrypoint = Entrypoint();
  entrypoint.attach(ActScreenplay(ActScenario.platformIsMocked, "family"));
  entrypoint.onStartApp();

  final CommandStore command = dep<CommandStore>();
  command.onCommandWithParam(CommandName.route.name, "home");

  runApp(const Root());
}
