import 'dart:io' as io;

import 'package:common/common/widget/app.dart';
import 'package:common/core/core.dart';
import 'package:common/modules.dart';
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
      : Flavor.v6;

  final PlatformType platform =
      io.Platform.isAndroid ? PlatformType.android : PlatformType.iOS;

  final modules = Modules();
  if (kReleaseMode) {
    await modules.create(ActScreenplay(ActScenario.prod, flavor, platform));
  } else {
    await modules
        .create(ActScreenplay(ActScenario.prodWithToys, flavor, platform));
  }

  if (flavor == Flavor.family) {
    jsonUrl = "https://family.api.blocka.net";
  }

  modules.start(Markers.start);

  // final ws = DevWebsocket();
  // depend(ws);
  // ws.handle();

  runApp(BlokadaApp(
    content:
        (flavor == Flavor.family) ? null : const Scaffolding(title: 'Blokada'),
  ));
}
