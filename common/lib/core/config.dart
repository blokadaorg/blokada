part of 'core.dart';

class CoreConfig {
  Duration appStartFailWait = const Duration(seconds: 5);
  Duration accountExpiringTimeSpan = const Duration(seconds: 30);
  Duration accountRefreshCooldown = const Duration(seconds: 60);
  Duration deviceRefreshCooldown = const Duration(seconds: 60);
  Duration plusLeaseRefreshCooldown = const Duration(seconds: 60);
  Duration plusGatewayRefreshCooldown = const Duration(seconds: 60);
  Duration plusVpnCommandTimeout = const Duration(seconds: 5);
  Duration statsRefreshWhenOnAnotherScreen = const Duration(seconds: 240);
  Duration refreshVeryFrequent = const Duration(seconds: 10);
  Duration refreshOnHome = const Duration(seconds: 120);

  bool obfuscateSensitiveParams = false;

  CoreConfig();

  testing() {
    const noWait = Duration(seconds: 0);
    appStartFailWait = noWait;
  }
}
