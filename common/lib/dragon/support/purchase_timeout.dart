import 'package:common/account/account.dart';
import 'package:common/common/model.dart';
import 'package:common/dragon/persistence/persistence.dart';
import 'package:common/dragon/support/controller.dart';
import 'package:common/dragon/value.dart';
import 'package:common/logger/logger.dart';
import 'package:common/scheduler/scheduler.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/async.dart';
import 'package:common/util/di.dart';

class PurchaseTimout with Logging {
  late final _stage = dep<StageStore>();
  late final _support = dep<SupportController>();
  late final _account = dep<AccountStore>();
  late final _scheduler = dep<Scheduler>();
  late final _notified = PurchaseTimeoutNotified();

  bool _userEnteredPurchase = false;
  final _timeoutSeconds = 27; // Time after going to bg, to send the event
  bool _justNotified = false;

  load() async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    await _notified.fetch();
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
    _notified.now = true;
    _justNotified = true;
    return false;
  }

  clearSendPurchaseTimeout() async {
    _notified.now = false;
    await _scheduler.stop("sendPurchaseTimeout");
  }
}

class PurchaseTimeoutNotified extends AsyncValue<bool> {
  late final _persistence = dep<Persistence>();

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
