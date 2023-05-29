import 'package:common/ui/myapp.dart';
import 'package:flutter/material.dart';

import 'entrypoint.dart';
import 'service/I18nService.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  await I18nService.loadTranslations();

  final entrypoint = Entrypoint();
  entrypoint.attach();
  entrypoint.onStartApp();

  runApp(const MyApp());
}
