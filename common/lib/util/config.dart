import 'package:flutter/foundation.dart';

import 'di.dart';

final cfg = Config();

class Config {
  late bool isTest = false;
  late bool logToConsole = true;
  late int httpMaxRetries = 2;
  late Duration httpRetryDelay = const Duration(seconds: 1);
  late Duration appStartFailWait = const Duration(seconds: 5);
  late Duration appPauseDuration = const Duration(seconds: 30);
  late Duration accountExpiringTimeSpan = const Duration(seconds: 30);
  late Duration accountRefreshCooldown = const Duration(seconds: 60);
  late Duration customRefreshCooldown = const Duration(seconds: 60);
  late Duration deckRefreshCooldown = const Duration(seconds: 60);
  late Duration deviceRefreshCooldown = const Duration(seconds: 60);
  late Duration journalRefreshCooldown = const Duration(seconds: 10);
  late Duration plusLeaseRefreshCooldown = const Duration(seconds: 60);
  late Duration plusGatewayRefreshCooldown = const Duration(seconds: 60);
  late Duration plusVpnCommandTimeout = const Duration(seconds: 5);
  late Duration statsRefreshWhenOnStatsScreen = const Duration(seconds: 30);
  late Duration statsRefreshWhenOnHomeScreen = const Duration(seconds: 120);
  late Duration statsRefreshWhenOnAnotherScreen = const Duration(seconds: 240);

  late DateTime? debugSendTracesUntil =
      _isInDebugMode ? DateTime.now().add(const Duration(minutes: 15)) : null;
  late Uri? debugSendTracesTo = _isInDebugMode
      ? Uri.parse("http://192.168.101.107:4318/v1/traces")
      : null;
  late List<String> debugFailingRequests = [];

  late Act act;

  testing() {
    const noWait = Duration(seconds: 0);
    httpRetryDelay = noWait;
    appStartFailWait = noWait;
  }
}

bool get _isInDebugMode {
  return !kReleaseMode;
}
