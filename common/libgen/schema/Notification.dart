import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class NotificationOps {
  @async
  void doShow(String notificationId, String atWhen, String? body);

  @async
  void doDismissAll();
}
