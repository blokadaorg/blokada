import 'dart:io';

import 'package:common/account/refresh/channel.pg.dart';
import 'package:mobx/mobx.dart';

import '../../notification/notification.dart';
import '../../stage/stage.dart';
import '../../timer/timer.dart';
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

const Duration _accountExpiringTimeSpan = Duration(seconds: 30);
const Duration _refreshInterval = Duration(minutes: 1);
const Duration _initFailRetryWait = Duration(seconds: 3);
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
      if (exp.isAfter(now.add(_accountExpiringTimeSpan))) {
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
      } else if (exp.isBefore(now.add(_accountExpiringTimeSpan))) {
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
      return expiration.subtract(_accountExpiringTimeSpan);
    } else if (status == AccountStatus.expiring) {
      return expiration;
    } else {
      return null;
    }
  }
}

enum AccountStatus { init, active, inactive, expiring, expired, fatal }

class AccountRefreshStore = AccountRefreshStoreBase with _$AccountRefreshStore;

abstract class AccountRefreshStoreBase with Store, Traceable {
  late final _timer = di<TimerService>();
  late final _account = di<AccountStore>();
  late final _notificationStore = di<NotificationStore>();

  bool _initSuccessful = false;

  @observable
  DateTime lastRefresh = DateTime(0);

  @observable
  AccountExpiration expiration = AccountExpiration.init();

  @observable
  int accountUpgrades = 0;

  AccountType? _previousAccountType;

  @action
  Future<void> init(Trace parentTrace) async {
    // On app start, try loading cache, then either refresh account from api,
    // or create a new one.
    return await traceWith(parentTrace, "init", (trace) async {
      if (_initSuccessful) throw StateError("already initialized");
      await _account.load(trace);
      await _account.fetch(trace);
      lastRefresh = DateTime.now();
      _initSuccessful = true;
    }, fallback: (trace) async {
      trace.addEvent("creating new account");
      await _account.create(trace);
      lastRefresh = DateTime.now();
    });
  }

  // This is called when the account is updated in AccountStore.
  // This means that the methods below will also cause this to be called.
  @action
  Future<void> update(Trace parentTrace, AccountState account) async {
    return await traceWith(parentTrace, "update", (trace) async {
      final hasExp = account.jsonAccount.activeUntil != null;
      DateTime? exp =
          hasExp ? DateTime.parse(account.jsonAccount.activeUntil!) : null;
      expiration = expiration.update(expiration: exp);
      _updateTimer(trace);

      // Track the previous account type so that we can notice when user upgrades
      if (account.type.isUpgradeOver(_previousAccountType)) {
        accountUpgrades++;
      }
      _previousAccountType = account.type;
    });
  }

  @action
  Future<void> maybeRefresh(Trace parentTrace, {bool force = false}) async {
    return await traceWith(parentTrace, "maybeRefresh", (trace) async {
      if (!_initSuccessful) {
        trace.addEvent("account not initialized yet");
        return;
      }

      if (force || DateTime.now().difference(lastRefresh) > _refreshInterval) {
        await _account.fetch(trace);
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
      lastRefresh = DateTime.now();
    }, fallback: (trace) async {
      // We may have cut off the internet, so we can't refresh.
      // Mark the account as expired manually.
      await _account.expireOffline(trace);
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

      _notificationStore.show(trace, NotificationId.accountExpired,
          when: expiration.expiration);
      trace.addAttribute("notificationId", NotificationId.accountExpired);
      trace.addAttribute("notificationDate", expiration.expiration);
    } else {
      _timer.unset(_keyTimer);
      trace.addAttribute("timer", null);

      _notificationStore.dismiss(trace, NotificationId.accountExpired);
      trace.addAttribute("notificationId", NotificationId.accountExpired);
      trace.addAttribute("notificationDate", null);
    }
  }
}

class AccountRefreshBinder with AccountRefreshEvents, Traceable, AppStarter {
  late final _store = di<AccountRefreshStore>();
  late final _stage = di<StageStore>();
  late final _timer = di<TimerService>();
  late final _account = di<AccountStore>();

  late final Duration _wait;

  AccountRefreshBinder() {
    _wait = _initFailRetryWait;
    AccountRefreshEvents.setup(this);
    _init();
  }

  AccountRefreshBinder.forTesting() {
    _wait = const Duration(seconds: 0);
    _init();
  }

  _init() {
    _onTimerFired();
    _onForeground();
    _onActiveTabIsSettings();
    _onAccountChanged();
    _onAccountUpgraded();
  }

  @override
  Future<void> startApp() async {
    await traceAs("startApp", (trace) async {
      await _initWithRetry(trace);
    }, fallback: (trace, e) async {
      await _stage.showModalNow(trace, StageModal.accountInitFailed);
      throw Exception("Failed to init account, displaying user modal");
    });
  }

  @override
  Future<void> onRetryInit() async {
    await traceAs("onRetryInit", (trace) async {
      _stage.dismissModal(trace);
      await _initWithRetry(trace);
    }, fallback: (trace, e) async {
      await _stage.showModalNow(trace, StageModal.accountInitFailed);
      throw Exception("Failed to retry init account, displaying user modal");
    });
  }

  // Init the account with a retry loop. Can be called multiple times if failed.
  Future<void> _initWithRetry(Trace trace) async {
    bool success = false;
    int attempts = 3;
    while (!success && attempts++ > 0) {
      try {
        await _store.init(trace);
        success = true;
      } on Exception catch (_) {
        trace.addEvent("init failed, retrying");
        sleep(_wait);
      }
    }

    if (!success) {
      return Future.error(Exception("Failed to init account"));
    }
  }

  // Set expiration timer handler
  _onTimerFired() {
    _timer.addHandler(_keyTimer, () async {
      await traceAs("onTimerFired", (trace) async {
        await _store.onTimerFired(trace);
      });
    });
  }

  // Refresh account on foreground (periodically)
  _onForeground() {
    reaction((_) => _stage.isForeground, (isForeground) async {
      if (isForeground) {
        await traceAs("onForeground", (trace) async {
          await _store.maybeRefresh(trace);
        });
      }
    });
  }

  // Refresh account on entering settings tab (always)
  _onActiveTabIsSettings() {
    reaction((_) => _stage.activeTab, (tab) async {
      if (tab == StageTab.settings) {
        await traceAs("onActiveTabIsSettings", (trace) async {
          await _store.maybeRefresh(trace, force: true);
        });
      }
    });
  }

  // Update account when changed by the upstream store
  _onAccountChanged() {
    reaction((_) => _account.account, (account) async {
      if (account != null) {
        await traceAs("onAccountChanged", (trace) async {
          await _store.update(trace, account);
        });
      }
    });
  }

  // Show the onboarding whenever account just got upgraded
  _onAccountUpgraded() {
    reaction((_) => _store.accountUpgrades, (_) async {
      await traceAs("onAccountUpgraded", (trace) async {
        await _stage.showModalNow(trace, StageModal.onboarding);
      });
    });
  }
}

abstract class AppStarter {
  Future<void> startApp();
}

Future<void> init() async {
  di.registerSingleton<AccountRefreshStore>(AccountRefreshStore());
  final binder = AccountRefreshBinder();
  di.registerSingleton<AccountRefreshEvents>(binder);
  di.registerSingleton<AppStarter>(binder);
}
