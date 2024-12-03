part of 'core.dart';

class Config {
  bool isTest = false;
  bool logToConsole = true;
  int httpMaxRetries = 2;
  Duration httpRetryDelay = const Duration(seconds: 1);
  Duration appStartFailWait = const Duration(seconds: 5);
  Duration appPauseDuration = const Duration(seconds: 30);
  Duration accountExpiringTimeSpan = const Duration(seconds: 30);
  Duration accountRefreshCooldown = const Duration(seconds: 60);
  Duration customRefreshCooldown = const Duration(seconds: 60);
  Duration deckRefreshCooldown = const Duration(seconds: 60);
  Duration deviceRefreshCooldown = const Duration(seconds: 60);
  Duration plusLeaseRefreshCooldown = const Duration(seconds: 60);
  Duration plusGatewayRefreshCooldown = const Duration(seconds: 60);
  Duration plusVpnCommandTimeout = const Duration(seconds: 5);
  Duration statsRefreshWhenOnAnotherScreen = const Duration(seconds: 240);
  Duration refreshVeryFrequent = const Duration(seconds: 10);
  Duration refreshOnHome = const Duration(seconds: 120);

  DateTime? debugSendTracesUntil = Core.act.isRelease
      ? null
      : DateTime.now().add(const Duration(minutes: 15));
  Uri? debugSendTracesTo = Core.act.isRelease
      ? null
      : Uri.parse("http://192.168.1.173:4318/v1/traces");
  List<String> debugFailingRequests = [];
  bool debugBg = false;

  testing() {
    const noWait = Duration(seconds: 0);
    httpRetryDelay = noWait;
    appStartFailWait = noWait;
  }
}
