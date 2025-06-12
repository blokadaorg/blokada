part of 'payment.dart';

class PlatformPaymentChannel with PaymentChannel {
  late final _ops = PaymentOps();

  @override
  Future<void> init(
          Marker m, String apiKey, AccountId? accountId, bool verboseLogs) =>
      _ops.doInit(apiKey, accountId, verboseLogs);

  @override
  Future<void> identify(AccountId accountId) => _ops.doIdentify(accountId);

  @override
  Future<void> preload(Marker m, Placement placement) => _ops.doPreload(placement.id);

  @override
  Future<void> showPaymentScreen(Marker m, Placement placement, {bool forceReload = false}) =>
      _ops.doShowPaymentScreen(placement.id, forceReload);

  @override
  Future<void> closePaymentScreen() => _ops.doClosePaymentScreen();

  @override
  Future<void> logOnboardingStep(String name, OnboardingStep step) =>
      _ops.doLogOnboardingStep(name, step.name, step.order);

  @override
  Future<void> setCustomAttributes(Marker m, Map<String, dynamic> attributes) =>
      _ops.doSetCustomAttributes(attributes);
}
