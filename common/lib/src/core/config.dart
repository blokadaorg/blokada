part of 'core.dart';

class CoreConfig {
  Duration appStartFailWait = const Duration(seconds: 5);
  Duration accountExpiringTimeSpan = const Duration(seconds: 30);
  Duration accountRefreshCooldown = const Duration(seconds: 60);
  Duration deviceRefreshCooldown = const Duration(seconds: 60);
  Duration plusLeaseRefreshCooldown = const Duration(seconds: 60);
  Duration plusGatewayRefreshCooldown = const Duration(seconds: 60);
  // Above the native start wait (3 attempts of 10s). A longer hold, such as
  // iOS swapping in an updated VPN extension, comes back as a pending start.
  Duration plusVpnCommandTimeout = const Duration(seconds: 35);
  Duration statsRefreshWhenOnAnotherScreen = const Duration(seconds: 240);
  Duration refreshVeryFrequent = const Duration(seconds: 5);
  Duration refreshOnHome = const Duration(seconds: 15);

  // Starts on in release so a cold start cannot log a token before ConfigActor
  // resolves the log level. ConfigActor only ever relaxes this.
  bool obfuscateSensitiveParams = kReleaseMode;

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
