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
  void doClosePaymentScreen(bool isError);

  @async
  void doSetCustomAttributes(Map<String, Object?> attributes);

  // Settings "Your plan" reads renewal state outside the paywall.
  @async
  List<OpsSubscription> doFetchActiveSubscriptions();

  // Settings "Restore purchases": the profile id when the restore granted an
  // active access level, null when there was nothing active to restore.
  @async
  String? doRestorePurchases();
}

// One active Adapty access level, as Settings needs it.
class OpsSubscription {
  String accessLevelId;
  // Adapty store id: app_store, play_store, stripe, adapty, ...
  String store;
  bool willRenew;
  // ISO 8601, null for lifetime access.
  String? expiresAt;

  OpsSubscription(this.accessLevelId, this.store, this.willRenew, this.expiresAt);
}
