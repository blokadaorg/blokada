import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'entrypoint.dart';
import 'service/I18nService.dart';
import 'ui/root.dart';
import 'util/act.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  const platform = MethodChannel('org.blokada/flavor');
  final String flavor = await platform.invokeMethod('getFlavor');

  final entrypoint = Entrypoint();
  if (kReleaseMode) {
    entrypoint.attach(ActScreenplay(ActScenario.prod, flavor));
  } else {
    entrypoint.attach(ActScreenplay(ActScenario.prodWithToys, flavor));
  }
  entrypoint.onStartApp();

  runApp(const Root());
}
