part of 'payment.dart';

mixin PaymentChannel {
  Future<void> init(Marker m, String apiKey, AccountId? accountId, bool verboseLogs);
  Future<void> identify(AccountId accountId);
  Future<void> logOnboardingStep(String name, OnboardingStep step);
  Future<void> preload(Marker m, Placement placement);
  Future<void> showPaymentScreen(Marker m, Placement placement, {bool forceReload = false});
  Future<void> closePaymentScreen(bool isError);
  Future<void> setCustomAttributes(Marker m, Map<String, dynamic> attributes);

  /// The active Adapty access levels, for Settings "Your plan". Only the store
  /// knows whether a subscription renews; the backend account has just the end
  /// date. Read-only: never restores or checks out.
  Future<List<StoreSubscription>> fetchActiveSubscriptions(Marker m);

  /// Restores store purchases outside the paywall (Settings). Returns the
  /// Adapty profile id when the restore granted an active access level, null
  /// otherwise; a restore without one must not run checkout (see #376).
  Future<String?> restorePurchases(Marker m);
}

/// One active Adapty access level. [store] is Adapty's store id (app_store,
/// play_store, stripe, adapty, ...); [expiresAt] is null for lifetime access.
/// [customerUserId] is the Adapty profile's customer (our account id), null
/// for an anonymous profile; levels of another customer must not describe
/// the current account.
class StoreSubscription {
  final String accessLevelId;
  final String store;
  final bool willRenew;
  final DateTime? expiresAt;
  final String? customerUserId;

  const StoreSubscription({
    required this.accessLevelId,
    required this.store,
    required this.willRenew,
    required this.expiresAt,
    required this.customerUserId,
  });
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
