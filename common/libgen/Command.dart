import 'package:pigeon/pigeon.dart';

enum CommandName {
  // Universal links / deep links
  url,

  // Account
  restore,
  account,

  // AppStart
  pause,
  unpause,

  // Notification,
  remoteNotification,

  // Stage
  foreground,
  background,
  route,
  modalShow,
  modalShown,
  modalDismiss,
  modalDismissed,
  back,

  // Tracer
  fatal,
  warning,
  log,
  crashLog,

  // Family commands
  familyLink,

  // Support
  supportNotify,
  supportAskNotificationPerms,

  // Scheduler
  schedulerPing,

  // Plus
  newPlus,
  vpnStatus,

  // Notification
  notificationTapped,
  appleNotificationToken,

  // Payment (temporary)
  paymentHandleSuccess,
  paymentHandleFailure,
  paymentHandleScreenClosed,
}

@HostApi()
abstract class CommandOps {
  @async
  void doCanAcceptCommands();
}

@FlutterApi()
abstract class CommandEvents {
  @async
  void onCommand(String command, int m);

  @async
  void onCommandWithParam(String command, String p1, int m);

  @async
  void onCommandWithParams(String command, String p1, String p2, int m);
}
