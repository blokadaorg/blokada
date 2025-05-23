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
  Duration refreshVeryFrequent = const Duration(seconds: 5);
  Duration refreshOnHome = const Duration(seconds: 15);

  bool obfuscateSensitiveParams = false;

  CoreConfig();

  testing() {
    const noWait = Duration(seconds: 0);
    appStartFailWait = noWait;
  }
}

// Used by support to ask for detailed logs when troubleshooting
// Provided by module/config but also used in core (in trace.dart)
class ConfigLogLevel extends StringPersistedValue {
  ConfigLogLevel() : super("config:logLevel");
}
