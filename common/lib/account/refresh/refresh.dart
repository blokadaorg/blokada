import 'package:mobx/mobx.dart';

import '../../app/app.dart';
import '../../device/device.dart';
import '../../env/env.dart';
import '../../event.dart';
import '../../notification/notification.dart';
import '../../plus/keypair/channel.pg.dart';
import '../../stage/stage.dart';
import '../../timer/timer.dart';
import '../../util/config.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../account.dart';

part 'refresh.g.dart';

/// AccountRefreshStore
///
/// Manages account expiration and refresh. It is responsible for:
/// - making sure AccountStore is initialized
/// - refreshing account periodically
/// - expiring account as per expiration date
/// - expiring account offline when no connectivity
///
/// It expects init() to be called before any other method.
/// It expects maybeRefresh() to be called on app foreground.
/// It expects onTimerFired() to be called by a timer.

const String _keyTimer = "account:expiration";

class AccountExpiration {
  final AccountStatus status;
  final DateTime expiration;

  AccountExpiration({
    required this.status,
    required this.expiration,
  });

  AccountExpiration.init()
      : this(
          status: AccountStatus.init,
          expiration: DateTime(0),
        );

  AccountExpiration update({DateTime? expiration}) {
    DateTime exp = expiration ?? this.expiration;
    DateTime now = DateTime.now();

    AccountStatus newStatus = AccountStatus.inactive;
    // Account wasn't active, and now is
    if (status == AccountStatus.inactive || status == AccountStatus.init) {
      if (exp.isAfter(now.add(cfg.accountExpiringTimeSpan))) {
        newStatus = AccountStatus.active;
      } else if (exp.isAfter(now)) {
        newStatus = AccountStatus.expiring;
      }
    }
    // Account was active, may be expiring now
    else {
      newStatus = AccountStatus.active;
      if (exp.isBefore(now)) {
        newStatus = AccountStatus.expired;
      } else if (exp.isBefore(now.add(cfg.accountExpiringTimeSpan))) {
        newStatus = AccountStatus.expiring;
      }
    }

    return AccountExpiration(status: newStatus, expiration: exp);
  }

  AccountExpiration markAsInactive() {
    return AccountExpiration(
        status: AccountStatus.inactive, expiration: expiration);
  }

  DateTime? getNextDate() {
    if (status == AccountStatus.active) {
      return expiration.subtract(cfg.accountExpiringTimeSpan);
    } else if (status == AccountStatus.expiring) {
      return expiration;
    } else {
      return null;
    }
  }
}

enum AccountStatus { init, active, inactive, expiring, expired, fatal }

class AccountRefreshStore = AccountRefreshStoreBase with _$AccountRefreshStore;

abstract class AccountRefreshStoreBase with Store, Traceable, Dependable {
  late final _event = di<EventBus>();
  late final _timer = di<TimerService>();
  late final _account = di<AccountStore>();
  late final _notification = di<NotificationStore>();
  late final _stage = di<StageStore>();

  AccountRefreshStoreBase() {
    _timer.addHandler(_keyTimer, onTimerFired);
  }

  @override
  attach() {
    depend<AccountRefreshStore>(this as AccountRefreshStore);
  }

  bool _initSuccessful = false;

  @observable
  DateTime lastRefresh = DateTime(0);

  @observable
  AccountExpiration expiration = AccountExpiration.init();

  AccountType? _previousAccountType;
  AccountId? _previousAccountId;

  @action
  Future<void> init(Trace parentTrace) async {
    // On app start, try loading cache, then either refresh account from api,
    // or create a new one.
    return await traceWith(parentTrace, "init", (trace) async {
      if (_initSuccessful) throw StateError("already initialized");
      await _account.load(trace);
      await _account.fetch(trace);
      await syncAccount(trace, _account.account);
      lastRefresh = DateTime.now();
      _initSuccessful = true;
    }, fallback: (trace) async {
      trace.addEvent("creating new account");
      await _account.create(trace);
      await syncAccount(trace, _account.account);
      lastRefresh = DateTime.now();
    });
  }

  // This has to be called when the account is updated in AccountStore.
  @action
  Future<void> syncAccount(Trace parentTrace, AccountState? account) async {
    return await traceWith(parentTrace, "syncAccount", (trace) async {
      if (account == null) return;

      final hasExp = account.jsonAccount.activeUntil != null;
      DateTime? exp =
          hasExp ? DateTime.parse(account.jsonAccount.activeUntil!) : null;
      expiration = expiration.update(expiration: exp);
      _updateTimer(trace);

      // Track the previous account type so that we can notice when user upgrades
      if (account.type.isUpgradeOver(_previousAccountType)) {
        await _event.onEvent(trace, CommonEvent.accountTypeChanged);
      }
      _previousAccountType = account.type;

      if (_previousAccountId != null && _previousAccountId != account.id) {
        await _event.onEvent(trace, CommonEvent.accountIdChanged);
      }
      _previousAccountId = account.id;

      await _event.onEvent(trace, CommonEvent.accountChanged);
    });
  }

  @action
  Future<void> maybeRefresh(Trace parentTrace, {bool force = false}) async {
    return await traceWith(parentTrace, "maybeRefresh", (trace) async {
      if (!_initSuccessful) {
        trace.addEvent("account not initialized yet");
        return;
      }

      if (!_stage.isForeground) {
        return;
      }

      if (force ||
          _stage.route.isTop(StageTab.settings) ||
          DateTime.now().difference(lastRefresh) > cfg.accountRefreshCooldown) {
        await _account.fetch(trace);
        await syncAccount(trace, _account.account);
        lastRefresh = DateTime.now();
        trace.addEvent("refreshed");
      } else {
        // Even when not refreshing, recheck the expiration on foreground
        expiration = expiration.update();
        _updateTimer(trace);
      }
    });
  }

  // This has to be hooked up to the timer callback.
  @action
  Future<void> onTimerFired(Trace parentTrace) async {
    return await traceWith(parentTrace, "onTimerFired", (trace) async {
      if (!_initSuccessful) throw StateError("account not initialized");
      expiration = expiration.update();
      // Maybe account got extended externally, so try to refresh
      // This will invoke the update() above.
      await _account.fetch(trace);
      await syncAccount(trace, _account.account);
      lastRefresh = DateTime.now();
    }, fallback: (trace) async {
      // We may have cut off the internet, so we can't refresh.
      // Mark the account as expired manually.
      await _account.expireOffline(trace);
      await syncAccount(trace, _account.account);
    });
  }

  // After user has seen the expiration message, mark the account as inactive.
  @action
  Future<void> markAsInactive(Trace parentTrace) async {
    return await traceWith(parentTrace, "markAsInactive", (trace) async {
      expiration = expiration.markAsInactive();
    });
  }

  void _updateTimer(Trace trace) {
    DateTime? expDate = expiration.getNextDate();
    if (expDate != null) {
      _timer.set(_keyTimer, expDate);
      trace.addAttribute("timer", expDate);

      _notification.show(trace, NotificationId.accountExpired,
          when: expiration.expiration);
      trace.addAttribute("notificationId", NotificationId.accountExpired);
      trace.addAttribute("notificationDate", expiration.expiration);
    } else {
      _timer.unset(_keyTimer);
      trace.addAttribute("timer", null);

      _notification.dismiss(trace, NotificationId.accountExpired);
      trace.addAttribute("notificationId", NotificationId.accountExpired);
      trace.addAttribute("notificationDate", null);
    }
  }
}
