import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class AppPauseOps {
  @async
  void doAppPauseDurationChanged(int seconds);
}

@FlutterApi()
abstract class AppPauseEvents {
  @async
  void onPauseApp(bool isIndefinitely);

  @async
  void onUnpauseApp();
}
