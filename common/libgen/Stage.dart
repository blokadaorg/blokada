import 'package:pigeon/pigeon.dart';

enum StageModal {
  help,
  onboardingFamily,
  payment,
  plusLocationSelect,
  debug,
  fault,
  faultLocked,
  faultLockInvalid,
  faultLinkAlready,
  accountChange,
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
