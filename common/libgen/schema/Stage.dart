import 'package:pigeon/pigeon.dart';

enum StageModal {
  help,
  perms,
  onboardingFamily,
  onboardingAccountDecided,
  // pause,
  payment,
  //paymentDetails,
  plusLocationSelect,
  debug,
  debugSharing,
  adsCounterShare,
  custom,
  // updatePrompt,
  // updateOngoing,
  // updateComplete,
  fault,
  faultLocked,
  faultLockInvalid,
  faultLinkAlready,
  accountChange,
  accountLink,
  accountInitFailed,
  accountRestoreFailed,
  accountRestoreIdOk,
  accountRestoreIdFailed,
  accountExpired,
  accountInvalid,
  plusTooManyLeases,
  plusVpnFailure,
  paymentUnavailable,
  paymentTempUnavailable,
  paymentFailed,
  deviceAlias,
  lock,
  rate,
  crash
}

@HostApi()
abstract class StageOps {
  @async
  void doShowModal(StageModal modal);

  @async
  void doDismissModal();

  @async
  void doOpenLink(String url);

  @async
  void doHomeReached();
}
