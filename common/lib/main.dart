import 'package:common/ui/myapp.dart';
import 'package:flutter/material.dart';

import 'account/account.dart' as account;
import 'account/payment/payment.dart' as account_payment;
import 'account/refresh/refresh.dart' as account_refresh;
import 'app/app.dart' as app;
import 'app/pause/pause.dart' as app_pause;
import 'device/device.dart' as device;
import 'perm/perm.dart' as perm;
import 'custom/custom.dart' as custom;
import 'custom/refresh/refresh.dart' as custom_refresh;
import 'env/env.dart' as env;
import 'http/http.dart' as http;
import 'journal/journal.dart' as journal;
import 'journal/refresh/refresh.dart' as journal_refresh;
import 'notification/notification.dart' as notification;
import 'persistence/persistence.dart' as persistence;
import 'service/I18nService.dart';
import 'stage/stage.dart' as stage;
import 'stats/refresh/refresh.dart' as stats_refresh;
import 'stats/stats.dart' as stats;
import 'timer/timer.dart' as timer;
import 'deck/deck.dart' as deck;
import 'deck/refresh/refresh.dart' as deck_refresh;
import 'ui/home/home.dart' as home;
import 'util/di.dart';

void main() async {
  // Needed for the MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  // Init all modules
  await env.init();
  await timer.init();
  await stage.init();
  await persistence.init();
  await http.init();
  await notification.init();
  await account.init();
  await account_refresh.init();
  await account_payment.init();
  await device.init();
  await perm.init();

  await app.init();
  await app_pause.init();

  await stats.init();
  await stats_refresh.init();

  await journal.init();
  await journal_refresh.init();
  await custom.init();
  await custom_refresh.init();

  await deck.init();
  await deck_refresh.init();

  await home.init();

  // This is the first thing that causes a HTTP request.
  final bind = di<app_pause.AppPauseBinder>();
  await bind.onStartApp();

  await I18nService.loadTranslations();
  runApp(const MyApp());
}
