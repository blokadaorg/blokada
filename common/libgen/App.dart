import 'package:pigeon/pigeon.dart';

enum AppStatus {
  unknown,
  initializing,
  initFail,
  reconfiguring,
  deactivated,
  paused,
  pausedPlus, // When app is paused with timer, but VPN stays active
  activatedCloud,
  activatedPlus
}

@HostApi()
abstract class AppOps {
  @async
  void doAppStatusChanged(AppStatus status);
}
