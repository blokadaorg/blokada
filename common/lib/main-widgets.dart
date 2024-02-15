import 'package:common/mock/via/mock_family.dart';
import 'package:common/mock/widget/mock_scaffolding.dart';
import 'package:common/util/trace.dart';
import 'package:flutter/material.dart';
import 'package:vistraced/via.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'command/command.dart';
import 'common/widget/app.dart';
import 'entrypoint.dart';
import 'service/I18nService.dart';
import 'util/act.dart';
import 'util/di.dart';

@Bootstrap(ViaAct(
  scenario: "production",
  platform: ViaPlatform.ios,
  flavor: "family",
))
void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  final entrypoint = Entrypoint();
  entrypoint
      .attach(ActScreenplay(ActScenario.prod, Flavor.family, Platform.ios));

  entrypoint.onStartApp();

  MockModule();
  injector.inject();

  final ws = DevWebsocket();
  depend(ws);
  ws.handle();

  // runApp(BlokadaApp(content: MockScaffoldingWidget()));
  runApp(BlokadaApp(content: null));
}

class DevWebsocket with TraceOrigin {
  var ip = "192.168.1.177";
  //var ip = "192.168.234.104";

  late final command = dep<CommandStore>();
  WebSocketChannel? channel;

  handle() async {
    channel = WebSocketChannel.connect(
      // Uri.parse('ws://192.168.1.176:8765'),
      Uri.parse('ws://$ip:8765'),
    );
    channel?.stream.listen((msg) async {
      traceAs("devwebsocket", (trace) => command.onCommandString(trace, msg));
    });
  }
}
