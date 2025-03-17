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
  Future<void> showPaymentScreen(Marker m, Placement placement) =>
      _ops.doShowPaymentScreen(placement.id);

  @override
  Future<void> closePaymentScreen() => _ops.doClosePaymentScreen();

  @override
  Future<void> logOnboardingStep(String name, OnboardingStep step) =>
      _ops.doLogOnboardingStep(name, step.name, step.order);
}
