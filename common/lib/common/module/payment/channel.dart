part of 'payment.dart';

mixin PaymentChannel {
  Future<void> init(
      Marker m, String apiKey, AccountId? accountId, bool verboseLogs);
  Future<void> identify(AccountId accountId);
  Future<void> logOnboardingStep(String name, OnboardingStep step);
  Future<void> showPaymentScreen(Marker m, Placement placement);
  Future<void> closePaymentScreen();
}

const cmdPaymentHandleSuccess = "paymentHandleSuccess";
const cmdPaymentHandleFailure = "paymentHandleFailure";

class PaymentCommand with Command, Logging {
  late final _actor = Core.get<PaymentActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand(cmdPaymentHandleSuccess, argsNum: 2, fn: cmdCheckout),
      registerCommand(cmdPaymentHandleFailure, argsNum: 2, fn: cmdFailure),
    ];
  }

  Future<void> cmdCheckout(Marker m, dynamic args) async {
    final profileId = args[0] as String;
    final restore = (args[0] as String) == "1";
    await _actor.checkoutSuccessfulPayment(profileId, restore: restore);
  }

  Future<void> cmdFailure(Marker m, dynamic args) async {
    final restore = (args[0] as String) == "1";
    final temporary = (args[1] as String) == "1";
    await _actor.handleFailure(
        m, "Adapty: failure from channel", Exception("Failure from channel"),
        restore: restore, temporary: temporary);
  }
}
