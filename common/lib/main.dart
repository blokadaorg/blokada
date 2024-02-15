import 'dart:io' as io;
import 'package:common/common/widget/family/home/home_screen.dart';
import 'package:common/json/json.dart';
import 'package:common/ui/family/family_scaffolding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vistraced/via.dart';

import 'common/widget/app.dart';
import 'entrypoint.dart';
import 'main-widgets.dart';
import 'mock/via/mock_family.dart';
import 'mock/via/temp_family.dart';
import 'mock/widget/mock_scaffolding.dart';
import 'service/I18nService.dart';
import 'ui/notfamily/scaffolding.dart';
import 'util/act.dart';
import 'util/di.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const channel = MethodChannel('org.blokada/flavor');

  final Flavor flavor = await channel.invokeMethod('getFlavor') == "family"
      ? Flavor.family
      : Flavor.og;

  final Platform platform =
      io.Platform.isAndroid ? Platform.android : Platform.ios;

  final entrypoint = Entrypoint();
  if (kReleaseMode) {
    entrypoint.attach(ActScreenplay(ActScenario.prod, flavor, platform));
  } else {
    entrypoint
        .attach(ActScreenplay(ActScenario.prodWithToys, flavor, platform));
  }

  if (flavor == Flavor.family) {
    jsonUrl = "https://family.api.blocka.net";
  }

  entrypoint.onStartApp();

  MockModule();
  TempModule();
  injector.inject();

  final ws = DevWebsocket();
  depend(ws);
  ws.handle();

  runApp(BlokadaApp(
    content: (flavor == Flavor.family)
        ? const HomeScreen()
        : const Scaffolding(title: 'Blokada'),
  ));
}
