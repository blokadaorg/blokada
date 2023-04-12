import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class NotificationOps {
  @async
  void doShow(String notificationId, String when);

  @async
  void doDismiss(String notificationId);
}

@FlutterApi()
abstract class NotificationEvents {
  @async
  void onUserAction(String notificationId);
}
