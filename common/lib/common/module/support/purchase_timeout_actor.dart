part of 'support.dart';

class PurchaseTimeoutActor with Logging, Actor {
  late final _stage = Core.get<StageStore>();
  late final _support = Core.get<SupportActor>();
  late final _account = Core.get<AccountStore>();
  late final _scheduler = Core.get<Scheduler>();
  late final _payment = Core.get<PaymentActor>();
  late final _notified = PurchaseTimeoutNotified();

  bool _userEnteredPurchase = false;
  final _timeoutSeconds = 27; // Time after going to bg, to send the event
  bool _justNotified = false;

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    await _notified.fetch(m);
    _support.onReset = clearSendPurchaseTimeout;

    _payment.onPaymentScreenOpened = () {
      _userEnteredPurchase = true;
    };
  }

  // Send support event when user abandoned purchase
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    // Coming back from BG, dismiss the payment modal if it's still there
    if (route.isBecameForeground() && _justNotified) {
      _justNotified = false;
      _payment.closePaymentScreen();
    }

    if ((await _notified.now()) == true) return;

    // Leaving to bg
    // Set a timeout event if user doesn't come back to the purchase screen
    if (!route.isForeground() && _userEnteredPurchase) {
      _userEnteredPurchase = false;
      await _scheduler.addOrUpdate(Job(
        "sendPurchaseTimeout",
        before: DateTime.now().add(Duration(seconds: _timeoutSeconds)),
        m,
        callback: sendPurchaseTimeout,
      ));
      return;
    }
  }

  Future<bool> sendPurchaseTimeout(Marker m) async {
    if (_account.type.isActive()) return false;
    await _support.sendEvent(SupportEvent.purchaseTimeout, m);
    await _notified.change(m, true);
    _justNotified = true;
    return false;
  }

  clearSendPurchaseTimeout(Marker m) async {
    await _notified.change(m, false);
    await _scheduler.stop(m, "sendPurchaseTimeout");
  }
}

class PurchaseTimeoutNotified extends BoolPersistedValue {
  PurchaseTimeoutNotified() : super("purchase_timeout_notified");
}
