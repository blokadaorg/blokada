import 'package:common/command/command.dart';
import 'package:common/common/i18n.dart';
import 'package:common/dragon/widget/app.dart';
import 'package:common/entrypoint.dart';
import 'package:common/util/act.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  final entrypoint = Entrypoint();
  entrypoint
      .attach(ActScreenplay(ActScenario.prod, Flavor.family, Platform.ios));

  entrypoint.onStartApp();

  final ws = DevWebsocket();
  depend(ws);
  ws.handle();

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
