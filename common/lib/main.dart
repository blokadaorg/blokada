import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
  if (kReleaseMode) {
    entrypoint.attach(ActScreenplay(ActScenario.prod));
  } else {
    entrypoint.attach(ActScreenplay(ActScenario.prodWithToys));
  }
  entrypoint.onStartApp();

  runApp(const Root());
}
