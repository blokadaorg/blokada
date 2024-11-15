import 'dart:io' as io;

import 'package:common/common/i18n.dart';
import 'package:common/dragon/app.dart';
import 'package:common/entrypoint.dart';
import 'package:common/json/json.dart';
import 'package:common/util/act.dart';
import 'package:common/util/di.dart';
import 'package:common/v6/widget/scaffolding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // final ws = DevWebsocket();
  // depend(ws);
  // ws.handle();

  runApp(BlokadaApp(
    content:
        (flavor == Flavor.family) ? null : const Scaffolding(title: 'Blokada'),
  ));
}
