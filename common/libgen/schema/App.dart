import 'package:pigeon/pigeon.dart';

enum AppStatus {
  unknown,
  initializing,
  reconfiguring,
  deactivated,
  paused,
  activatedCloud,
  activatedPlus
}

@HostApi()
abstract class AppOps {
  @async
  void doAppStatusChanged(AppStatus status);
}
