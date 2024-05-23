import 'dart:convert';

import 'package:common/account/refresh/json.dart';
import 'package:mobx/mobx.dart';

import '../../dragon/family/family.dart';
import '../../notification/notification.dart';
import '../../persistence/persistence.dart';
import '../../plus/plus.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../timer/timer.dart';
import '../../util/async.dart';
import '../../util/config.dart';
import '../../util/cooldown.dart';
import '../../util/di.dart';
import '../../util/emitter.dart';
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
const String _keyRefresh = "account:refresh";

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

abstract class AccountRefreshStoreBase
    with Store, Traceable, Dependable, Startable, Cooldown, Emitter {
  late final _timer = dep<TimerService>();
  late final _account = dep<AccountStore>();
  late final _notification = dep<NotificationStore>();
  late final _stage = dep<StageStore>();
  late final _persistence = dep<PersistenceService>();
  late final _plus = dep<PlusStore>();
  late final _family = dep<FamilyStore>();

  AccountRefreshStoreBase() {
    _timer.addHandler(_keyTimer, onTimerFired);
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  @override
  attach(Act act) {
    depend<AccountRefreshStore>(this as AccountRefreshStore);
  }

  @observable
  DateTime lastRefresh = DateTime(0);

  @observable
  AccountExpiration expiration = AccountExpiration.init();

  bool _initSuccessful = false;

  JsonAccRefreshMeta _metadata = JsonAccRefreshMeta();

  // Init the account with a retry loop. Can be called multiple times if failed.
  @action
  Future<void> start(Trace parentTrace) async {
    return await traceWith(parentTrace, "start", (trace) async {
      bool success = false;
      int retries = 2;
      Exception? lastException;
      while (!success && retries-- > 0) {
        try {
          await init(trace);
          success = true;
        } on Exception catch (e) {
          lastException = e;
          trace.addEvent("init failed, retrying");
          await sleepAsync(cfg.appStartFailWait);
        }
      }

      if (!success) {
        throw lastException ??
            Exception("Failed to start app for unknown reason");
      }
    });
  }

  @action
  Future<void> init(Trace parentTrace) async {
    // On app start, try loading cache, then either refresh account from api,
    // or create a new one.
    return await traceWith(parentTrace, "init", (trace) async {
      if (_initSuccessful) throw StateError("already initialized");
      await _account.load(trace);
      await _account.fetch(trace);
      final metadataJson = await _persistence.load(trace, _keyRefresh);
      if (metadataJson != null) {
        _metadata = JsonAccRefreshMeta.fromJson(jsonDecode(metadataJson));
      }
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
      final prev = _metadata.previousAccountType;
      if (account.type.isUpgradeOver(prev)) {
        // User upgraded
        _metadata.seenExpiredDialog = false;
        await _saveMetadata(trace);
      } else if (account.type == AccountType.libre &&
          prev != AccountType.libre &&
          prev != null) {
        // Expired, show dialog if not seen for this expiration
        if (!_metadata.seenExpiredDialog) {
          _metadata.seenExpiredDialog = true;
          await _saveMetadata(trace);
          await _stage.showModal(trace, StageModal.accountExpired);
          if (!act.isFamily()) await _plus.clearPlus(trace);
        }
      }

      _metadata.previousAccountType = account.type;
      await _saveMetadata(trace);
    });
  }

  // After user has seen the expiration message, mark the account as inactive.
  @action
  Future<void> markAsInactive(Trace parentTrace) async {
    return await traceWith(parentTrace, "markAsInactive", (trace) async {
      expiration = expiration.markAsInactive();
    });
  }

  @action
  Future<void> onTimerFired(Trace parentTrace) async {
    return await traceWith(parentTrace, "onTimerFired", (trace) async {
      if (!_initSuccessful) return;
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

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (!_initSuccessful) return;
    if (!route.isForeground()) return;

    return await traceWith(parentTrace, "refreshExpiration", (trace) async {
      // Refresh when entering the Settings tab, or foreground after enough time
      if (route.isBecameTab(StageTab.settings) ||
          isCooledDown(cfg.accountRefreshCooldown)) {
        await _account.fetch(trace);
        await syncAccount(trace, _account.account);
      } else {
        // Even when not refreshing, recheck the expiration on foreground
        expiration = expiration.update();
        _updateTimer(trace);
      }
    });
  }

  @action
  Future<void> onRemoteNotification(Trace parentTrace) async {
    return await traceWith(parentTrace, "onRemoteNotification", (trace) async {
      // We use remote notifications pushed from the cloud to let the client
      // know that the account has been extended.
      await _account.fetch(trace);
      await syncAccount(trace, _account.account);
    });
  }

  void _updateTimer(Trace trace) {
    final id = act.isFamily()
        ? NotificationId.accountExpiredFamily
        : NotificationId.accountExpired;

    final shouldSkipNotification = act.isFamily() && _family.linkedMode;

    DateTime? expDate = expiration.getNextDate();
    if (expDate != null && !shouldSkipNotification) {
      _timer.set(_keyTimer, expDate);
      trace.addAttribute("timer", expDate);

      _notification.show(trace, id, when: expiration.expiration);
      trace.addAttribute("notificationId", id);
      trace.addAttribute("notificationDate", expiration.expiration);
    } else {
      _timer.unset(_keyTimer);
      trace.addAttribute("timer", null);

      _notification.dismiss(trace, id: id);
      trace.addAttribute("notificationId", id);
      trace.addAttribute("notificationDate", null);
    }
  }

  _saveMetadata(Trace trace) async {
    await _persistence.saveString(
        trace, _keyRefresh, jsonEncode(_metadata.toJson()));
  }
}
