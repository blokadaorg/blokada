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

  // No store on the simulator: Settings falls back to the account's end date.
  // MOCK_TRIAL_DAY=N fakes a 7 day store trial on its day N, so Home's trial
  // line (#460) can be shown on the simulator.
  @override
  Future<List<StoreSubscription>> fetchActiveSubscriptions(Marker m) async {
    const trialDay = int.fromEnvironment('MOCK_TRIAL_DAY');
    if (trialDay <= 0) return [];
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - (trialDay - 1), 9);
    return [
      StoreSubscription(
        accessLevelId: 'premium',
        store: 'app_store',
        willRenew: true,
        expiresAt: start.add(const Duration(days: 7)),
        customerUserId: null,
        activatedAt: start,
        introOfferType: 'free_trial',
      ),
    ];
  }

  @override
  Future<String?> restorePurchases(Marker m) async => null;
}
