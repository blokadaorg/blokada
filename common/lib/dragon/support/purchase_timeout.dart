import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/support/controller.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';

class PurchaseTimout with Logging, Actor {
  late final _stage = DI.get<StageStore>();
  late final _support = DI.get<SupportController>();
  late final _account = DI.get<AccountStore>();
  late final _scheduler = DI.get<Scheduler>();
  late final _notified = PurchaseTimeoutNotified();

  bool _userEnteredPurchase = false;
  final _timeoutSeconds = 27; // Time after going to bg, to send the event
  bool _justNotified = false;

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    await _notified.fetch(m);
    _support.onReset = clearSendPurchaseTimeout;
  }

  // Send support event when user abandoned purchase
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    // Coming back from BG, dismiss the payment modal if it's still there
    if (route.isBecameForeground() && _justNotified) {
      _justNotified = false;
      if (route.modal == StageModal.payment) {
        await sleepAsync(const Duration(milliseconds: 500));
        await _stage.dismissModal(m);
      }
    }

    if (_notified.now) return;

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

    if (route.modal == StageModal.payment) {
      _userEnteredPurchase = true;
    }
  }

  Future<bool> sendPurchaseTimeout(Marker m) async {
    if (_account.type.isActive()) return false;
    await _support.sendEvent(SupportEvent.purchaseTimeout, m);
    _notified.change(m, true);
    _justNotified = true;
    return false;
  }

  clearSendPurchaseTimeout(Marker m) async {
    _notified.change(m, false);
    await _scheduler.stop("sendPurchaseTimeout");
  }
}

class PurchaseTimeoutNotified extends AsyncValue<bool> {
  late final _persistence = DI.get<Persistence>();

  static const key = "purchase_timeout_notified";

  @override
  Future<bool> doLoad() async {
    return (await _persistence.load(key)) == "1";
  }

  @override
  doSave(bool value) async {
    await _persistence.save(key, value ? "1" : "0");
  }
}
