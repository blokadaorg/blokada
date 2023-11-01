import 'package:common/stage/stage.dart';
import 'package:common/util/trace.dart';
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

  MockedStart().start();
}

// In mocked, manually trigger the foreground
class MockedStart with TraceOrigin {
  late final StageStore _stage = dep<StageStore>();

  Future<void> start() async {
    await traceAs("mockedStart", (trace) async {
      await _stage.setForeground(trace);
    });
  }
}
