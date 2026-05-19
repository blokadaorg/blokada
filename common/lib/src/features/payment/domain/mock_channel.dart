part of 'payment.dart';

/// Simulator-only no-op PaymentChannel.
///
/// Registered by [PlatformPaymentModule] when [ActScenario.platformIsMocked]
/// is active so Adapty's StoreKit2-backed SDK is never initialised. Adapty
/// cannot fetch products on iOS Simulator (StoreKit2 limitation), so any
/// real init would hang or crash. The mocked entry points also pre-seed an
/// active account into secure storage, which means [showPaymentScreen]
/// should never be reached in practice — it logs a warning if it is.
class MockPaymentChannel with Logging, PaymentChannel {
  @override
  Future<void> init(Marker m, String apiKey, AccountId? accountId, bool verboseLogs) async {
    log(m).i("MockPaymentChannel: Adapty init skipped (mocked scheme)");
  }

  @override
  Future<void> identify(AccountId accountId) async {}

  @override
  Future<void> logOnboardingStep(String name, OnboardingStep step) async {}

  @override
  Future<void> preload(Marker m, Placement placement) async {}

  @override
  Future<void> showPaymentScreen(Marker m, Placement placement, {bool forceReload = false}) async {
    log(m).w("MockPaymentChannel: showPaymentScreen is a no-op in mocked scheme; placement=${placement.id}. Set ACCOUNT_ID env var (or .env.local) to seed a dev account. See ios/SIMULATOR.md.");
  }

  @override
  Future<void> closePaymentScreen(bool isError) async {}

  @override
  Future<void> setCustomAttributes(Marker m, Map<String, dynamic> attributes) async {}
}
