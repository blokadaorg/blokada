import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class PaymentOps {
  @async
  void doInit(String apiKey, String? accountId, bool verboseLogs);

  @async
  void doIdentify(String accountId);

  @async
  void doLogOnboardingStep(String name, String stepName, int stepOrder);

  @async
  void doPreload(String placementId);

  @async
  void doShowPaymentScreen(String placementId, bool forceReload);

  @async
  void doClosePaymentScreen();
}
