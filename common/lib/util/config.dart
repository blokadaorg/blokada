class Config {
  late int httpMaxRetries = 3;
  late Duration httpRetryDelay = const Duration(seconds: 1);
  late Duration appStartFailWait = const Duration(seconds: 5);
  late Duration appPauseDuration = const Duration(seconds: 30);
  late Duration accountExpiringTimeSpan = const Duration(seconds: 30);
  late Duration accountRefreshCooldown = const Duration(minutes: 1);
  late Duration customRefreshCooldown = const Duration(seconds: 10);
  late Duration deckRefreshCooldown = const Duration(seconds: 10);
  late Duration deviceRefreshCooldown = const Duration(seconds: 10);
  late Duration journalRefreshCooldown = const Duration(seconds: 10);
  late Duration plusLeaseRefreshCooldown = const Duration(seconds: 10);
  late Duration plusVpnCommandTimeout = const Duration(seconds: 5);
  late Duration statsRefreshWhenOnStatsScreen = const Duration(seconds: 30);
  late Duration statsRefreshWhenOnHomeScreen = const Duration(seconds: 120);
  late Duration statsRefreshWhenOnAnotherScreen = const Duration(seconds: 240);

  testing() {
    const noWait = Duration(seconds: 0);
    httpRetryDelay = noWait;
    appStartFailWait = noWait;
  }
}

final cfg = Config();
