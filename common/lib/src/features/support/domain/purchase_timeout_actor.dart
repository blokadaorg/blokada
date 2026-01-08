part of 'support.dart';

class PurchaseTimeoutActor with Logging, Actor {
  late final _stage = Core.get<StageStore>();
  late final _support = Core.get<SupportActor>();
  late final _account = Core.get<AccountStore>();
  late final _scheduler = Core.get<Scheduler>();
  late final _payment = Core.get<PaymentActor>();
  late final _notified = PurchaseTimeoutNotified();

  bool _userEnteredPurchase = false;
  bool _isPurchaseOpened = false;

  final _timeoutSeconds = 27; // Time after going to bg, to send the event
  bool _justNotified = false;

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    await _notified.fetch(m);
    _support.onReset = clearSendPurchaseTimeout;

    _payment.onPaymentScreenOpened = (opened) {
      _userEnteredPurchase = opened || _userEnteredPurchase;
      _isPurchaseOpened = opened;
    };
  }

  // Send support event when user abandoned purchase
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    // Coming back from BG, dismiss the payment modal if it's still there
    if (route.isBecameForeground() && _justNotified) {
      _justNotified = false;
      _payment.closePaymentScreen(m, isError: false);
    }

    if ((await _notified.now()) == true) return;
    if (_account.type.isActive()) return;

    // Leaving to bg
    // Set a timeout event if user doesn't come back to the purchase screen
    if (_shouldTriggerCheck(route.isForeground())) {
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
    if (!_shouldTriggerNotification()) return false;

    await _support.sendEvent(SupportEvent.purchaseTimeout, m);
    await _notified.change(m, true);
    _justNotified = true;
    return false;
  }

  clearSendPurchaseTimeout(Marker m) async {
    await _notified.change(m, false);
    await _scheduler.stop(m, "sendPurchaseTimeout");
  }

  // Checks if user abandoned the purchase, to trigger the timeout event
  bool _shouldTriggerCheck(bool isForeground) {
    if (Core.act.isIos) {
      // On iOS, we trigger if user opened the screen and then just left the app
      return !isForeground && _userEnteredPurchase;
    } else {
      // On Android, we can't use same trigger since app will report background
      // when the billing UI shows. Instead, we trigger if user opened the
      // paywall and then closed it and left the app without activating.
      return !isForeground && _userEnteredPurchase && !_isPurchaseOpened;
    }
  }

  // Checks after the timeout, if conditions are still valid to notify user
  bool _shouldTriggerNotification() {
    if (_account.type.isActive()) return false;
    if (_justNotified) return false;

    // On Android, we need to be more selective, because the billing UI
    // will show up and then the app will go to background, so we need to
    // check if user is still not during the normal purchase flow.
    if (Core.act.isAndroid && _isPurchaseOpened) {
      return false;
    }

    return true;
  }
}

class PurchaseTimeoutNotified extends BoolPersistedValue {
  PurchaseTimeoutNotified() : super("purchase_timeout_notified");
}
