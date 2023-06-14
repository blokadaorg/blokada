import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class AppStartOps {
  @async
  void doAppPauseDurationChanged(int seconds);
}
