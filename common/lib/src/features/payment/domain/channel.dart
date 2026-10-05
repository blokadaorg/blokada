part of 'payment.dart';

mixin PaymentChannel {
  Future<void> init(Marker m, String apiKey, AccountId? accountId, bool verboseLogs);
  Future<void> identify(AccountId accountId);
  Future<void> logOnboardingStep(String name, OnboardingStep step);
  Future<void> preload(Marker m, Placement placement);
  Future<void> showPaymentScreen(Marker m, Placement placement, {bool forceReload = false});
  Future<void> closePaymentScreen(bool isError);
  Future<void> setCustomAttributes(Marker m, Map<String, dynamic> attributes);
}

const cmdPaymentHandleSuccess = "paymentHandleSuccess";
const cmdPaymentHandleFailure = "paymentHandleFailure";
const cmdPaymentHandleScreenClosed = "paymentHandleScreenClosed";

/// Receives payment results from the Android six paywall, which runs natively
/// and reports back as commands with positional "0"/"1" string args.
class PaymentCommand with Command, Logging {
  late final _actor = Core.get<PaymentActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand(cmdPaymentHandleSuccess, argsNum: 2, fn: cmdCheckout),
      registerCommand(cmdPaymentHandleFailure, argsNum: 2, fn: cmdFailure),
      registerCommand(cmdPaymentHandleScreenClosed, argsNum: 1, fn: cmdScreenClosed),
    ];
  }

  /// Args: [profileId, restore]. The restore flag picks the restore-failed
  /// modal over payment-failed if the account check after checkout fails.
  Future<void> cmdCheckout(Marker m, dynamic args) async {
    final profileId = args[0] as String;
    final restore = (args[1] as String) == "1";
    await _actor.checkoutSuccessfulPayment(profileId, restore: restore);
  }

  Future<void> cmdFailure(Marker m, dynamic args) async {
    final restore = (args[0] as String) == "1";
    final temporary = (args[1] as String) == "1";
    await _actor.handleFailure(m, "Adapty: failure from channel", Exception("Failure from channel"),
        restore: restore, temporary: temporary);
  }

  Future<void> cmdScreenClosed(Marker m, dynamic args) async {
    final isError = (args[0] as String) == "1";
    await _actor.handleScreenClosed(m, isError: isError);
  }
}
