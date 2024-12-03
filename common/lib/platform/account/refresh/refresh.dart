import 'dart:convert';

import 'package:common/core/core.dart';
import 'package:common/platform/account/refresh/json.dart';
import 'package:mobx/mobx.dart';

import '../../../family/module/family/family.dart';
import '../../../util/cooldown.dart';
import '../../notification/notification.dart';
import '../../plus/plus.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
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
      if (exp.isAfter(now.add(Core.config.accountExpiringTimeSpan))) {
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
      } else if (exp.isBefore(now.add(Core.config.accountExpiringTimeSpan))) {
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
      return expiration.subtract(Core.config.accountExpiringTimeSpan);
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
    with Store, Logging, Actor, Cooldown, Emitter {
  late final _scheduler = Core.get<Scheduler>();
  late final _account = Core.get<AccountStore>();
  late final _notification = Core.get<NotificationStore>();
  late final _stage = Core.get<StageStore>();
  late final _persistence = Core.get<Persistence>();
  late final _plus = Core.get<PlusStore>();
  late final _linkedMode = Core.get<FamilyLinkedMode>();

  AccountRefreshStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  @override
  onRegister() {
    Core.register<AccountRefreshStore>(this as AccountRefreshStore);
  }

  @observable
  DateTime lastRefresh = DateTime(0);

  @observable
  AccountExpiration expiration = AccountExpiration.init();

  bool _initSuccessful = false;

  JsonAccRefreshMeta _metadata = JsonAccRefreshMeta();

  // Init the account with a retry loop. Can be called multiple times if failed.
  @override
  Future<void> onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      bool success = false;
      int retries = 2;
      Exception? lastException;
      while (!success && retries-- > 0) {
        try {
          await init(m);
          success = true;
        } on Exception catch (e) {
          lastException = e;
          log(m).i("init failed, retrying");
          await sleepAsync(Core.config.appStartFailWait);
        }
      }

      if (!success) {
        throw lastException ??
            Exception("Failed to start app for unknown reason");
      }
    });
  }

  @action
  Future<void> init(Marker m) async {
    // On app start, try loading cache, then either refresh account from api,
    // or create a new one.
    return await log(m).trace("init", (m) async {
      try {
        if (_initSuccessful) throw StateError("already initialized");
        await _account.load(m);
        await _account.fetch(m);
        final metadataJson = await _persistence.load(m, _keyRefresh);
        if (metadataJson != null) {
          _metadata = JsonAccRefreshMeta.fromJson(jsonDecode(metadataJson));
        }
        await syncAccount(_account.account, m);
        lastRefresh = DateTime.now();
        _initSuccessful = true;
      } catch (e) {
        log(m).i("creating new account");
        await _account.create(m);
        await syncAccount(_account.account, m);
        lastRefresh = DateTime.now();
        _initSuccessful = true;
      }
    });
  }

  // This has to be called when the account is updated in AccountStore.
  @action
  Future<void> syncAccount(AccountState? account, Marker m) async {
    return await log(m).trace("syncAccount", (m) async {
      if (account == null) return;

      final hasExp = account.jsonAccount.activeUntil != null;
      DateTime? exp =
          hasExp ? DateTime.parse(account.jsonAccount.activeUntil!) : null;
      expiration = expiration.update(expiration: exp);
      _updateTimer(m);

      // Track the previous account type so that we can notice when user upgrades
      final prev = _metadata.previousAccountType;
      if (account.type.isUpgradeOver(prev)) {
        // User upgraded
        _metadata.seenExpiredDialog = false;
        await _saveMetadata(m);
      } else if (account.type == AccountType.libre &&
          prev != AccountType.libre &&
          prev != null) {
        // Expired, show dialog if not seen for this expiration
        if (!_metadata.seenExpiredDialog) {
          _metadata.seenExpiredDialog = true;
          await _saveMetadata(m);
          await _stage.showModal(StageModal.accountExpired, m);
          if (!Core.act.isFamily) await _plus.clearPlus(m);
        }
      }

      _metadata.previousAccountType = account.type;
      await _saveMetadata(m);
    });
  }

  // After user has seen the expiration message, mark the account as inactive.
  @action
  Future<void> markAsInactive(Marker m) async {
    return await log(m).trace("markAsInactive", (m) async {
      expiration = expiration.markAsInactive();
    });
  }

  @action
  Future<bool> onTimerFired(Marker m) async {
    return await log(m).trace("onTimerFired", (m) async {
      try {
        if (!_initSuccessful) return false;
        log(m).i("timer fired, init successful");
        expiration = expiration.update();
        // Maybe account got extended externally, so try to refresh
        // This will invoke the update() above.
        await _account.fetch(m);
        await syncAccount(_account.account, m);
        lastRefresh = DateTime.now();
      } catch (e) {
        // We may have cut off the internet, so we can't refresh.
        // Mark the account as expired manually.
        await _account.expireOffline(m);
        await syncAccount(_account.account, m);
      }

      return false;
    });
  }

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!_initSuccessful) return;
    if (!route.isForeground()) return;

    return await log(m).trace("refreshExpiration", (m) async {
      // Refresh when entering the Settings tab, or foreground after enough time
      if (route.isBecameTab(StageTab.settings) ||
          isCooledDown(Core.config.accountRefreshCooldown)) {
        await _account.fetch(m);
        await syncAccount(_account.account, m);
      } else {
        // Even when not refreshing, recheck the expiration on foreground
        expiration = expiration.update();
        _updateTimer(m);
      }
    });
  }

  @action
  Future<void> onRemoteNotification(Marker m) async {
    return await log(m).trace("onRemoteNotification", (m) async {
      // We use remote notifications pushed from the cloud to let the client
      // know that the account has been extended.
      await _account.fetch(m);
      await syncAccount(_account.account, m);
    });
  }

  void _updateTimer(Marker m) async {
    final id = Core.act.isFamily
        ? NotificationId.accountExpiredFamily
        : NotificationId.accountExpired;

    final shouldSkipNotification = Core.act.isFamily && _linkedMode.now;

    DateTime? expDate = expiration.getNextDate();

    if (expDate != null && !shouldSkipNotification) {
      await _scheduler.addOrUpdate(Job(
        _keyTimer,
        m,
        before: expDate,
        callback: onTimerFired,
      ));

      _notification.show(id, when: expiration.expiration, m);
      log(m).pair("notificationId", id);
      log(m).pair("notificationDate", expiration.expiration);
    } else {
      await _scheduler.stop(m, _keyTimer);
      log(m).pair("timer", null);

      if (expiration.status == AccountStatus.active) {
        _notification.dismiss(id: id, m);
        log(m).pair("notificationId", id);
        log(m).pair("notificationDate", null);
      }
    }
  }

  _saveMetadata(Marker m) async {
    await _persistence.save(m, _keyRefresh, jsonEncode(_metadata.toJson()));
  }
}
