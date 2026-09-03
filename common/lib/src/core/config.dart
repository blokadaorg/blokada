part of 'core.dart';

class CoreConfig {
  Duration appStartFailWait = const Duration(seconds: 5);
  Duration accountExpiringTimeSpan = const Duration(seconds: 30);
  Duration accountRefreshCooldown = const Duration(seconds: 60);

  // How long one lapse owns the "account expired" notification. The backend
  // restamps active_until on every repeat webhook for a lapsed account, so the
  // expiry cannot key the guard; this floor does. Longer than any restamp
  // burst, far shorter than the shortest paid plan, and a renewal clears the
  // mark anyway.
  Duration accountExpiredNotificationCooldown = const Duration(days: 7);
  Duration deviceRefreshCooldown = const Duration(seconds: 60);
  Duration plusLeaseRefreshCooldown = const Duration(seconds: 60);
  Duration plusGatewayRefreshCooldown = const Duration(seconds: 60);
  Duration plusVpnCommandTimeout = const Duration(seconds: 5);
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
