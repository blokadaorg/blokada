import 'package:flutter/material.dart';

import 'command/channel.pg.dart';
import 'entrypoint.dart';
import 'service/I18nService.dart';
import 'ui/root.dart';
import 'util/act.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  final entrypoint = Entrypoint();
  entrypoint.attach(ActScreenplay(ActScenario.platformIsMocked));
  entrypoint.onStartApp();
  entrypoint.onCommandWithParam(CommandName.route.name, "home");

  runApp(const Root());
}
