import 'package:pigeon/pigeon.dart';

enum CommandName {
  // Universal links / deep links
  url,

  // Config
  setFlavor,

  // Account
  restore,
  account,

  // AccountPayment
  receipt,
  fetchProducts,
  purchase,
  changeProduct,
  restorePayment,

  // AppStart
  pause,
  unpause,

  // Custom
  allow,
  deny,
  delete,

  // Deck
  enableDeck,
  disableDeck,
  toggleListByTag,

  // Device
  enableCloud,
  disableCloud,
  setRetention,
  deviceAlias,
  setSafeSearch,

  // Journal
  sortNewest,
  sortCount,
  search,
  filter,
  filterDevice,

  // Notification,
  remoteNotification,
  appleNotificationToken,

  // Plus
  newPlus,
  clearPlus,
  activatePlus,
  deactivatePlus,

  // PlusLease
  deleteLease,

  // PlusVpn
  vpnStatus,

  // Stage
  foreground,
  background,
  route,
  modalShow,
  modalShown,
  modalDismiss,
  modalDismissed,
  back,

  // Lock
  setPin,
  unlock,

  // Tracer
  fatal,
  warning,
  log,
  crashLog,
  canPromptCrashLog,

  // Family commands
  familyLink,

  // Support
  supportNotify,

  // Debug
  debugHttpFail,
  debugHttpOk,
  debugOnboard,
  debugBg,
  mock,
  s, // scenario
  ws // websocket
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
