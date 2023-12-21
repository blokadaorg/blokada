import 'dart:io' as io;
import 'package:common/json/json.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'entrypoint.dart';
import 'service/I18nService.dart';
import 'ui/root.dart';
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

  runApp(const Root());
}
