import 'dart:convert';

import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/refresh/json.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:mobx/mobx.dart';

import 'package:common/src/app_variants/family/module/family/family.dart';
import '../../../util/cooldown.dart';
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
    return AccountExpiration(status: AccountStatus.inactive, expiration: expiration);
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

abstract class AccountRefreshStoreBase with Store, Logging, Actor, Cooldown, Emitter {
  late final _scheduler = Core.get<Scheduler>();
  late final _account = Core.get<AccountStore>();
  late final _notification = Core.get<NotificationActor>();
  late final _stage = Core.get<StageStore>();
  late final _persistence = Core.get<Persistence>();
  late final _securePersistence = Core.get<Persistence>(tag: Persistence.secure);
  late final _plus = Core.get<PlusActor>();
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
  bool _metadataLoaded = false;
  Future<void>? _metadataLoading;

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
        throw lastException ?? Exception("Failed to start app for unknown reason");
      }
    });
  }

  @action
  Future<void> init(Marker m) async {
    // On app start, try loading cache, then either refresh account from api,
    // or create a new one.
    if (_initSuccessful) throw StateError("already initialized");

    return await log(m).trace("init", (m) async {
      final cachedAccount = await _resolveCachedAccount(m);
      bool shouldCreateAccount = cachedAccount == null;

      if (!shouldCreateAccount) {
        try {
          await _account.fetch(m);
        } on HttpCodeException catch (e) {
          if (_shouldReplaceCachedAccount(e)) {
            log(m).w("cached account became invalid, creating a new one: $e");
            await _securePersistence.delete(m, keyAccount, isBackup: true);
            _account.account = null;
            shouldCreateAccount = true;
          } else {
            log(m).w("using cached account after refresh failure: $e");
          }
        } catch (e) {
          log(m).w("using cached account after refresh failure: $e");
        }
      }

      if (shouldCreateAccount) {
        log(m).i("creating new account");
        await _account.createAccount(m);
        _metadata = JsonAccRefreshMeta();
        _metadataLoaded = true;
        await _persistence.delete(m, _keyRefresh);
        await syncAccount(_account.account, m);
      } else {
        await _ensureMetadataLoaded(m);
        await syncAccount(_account.account ?? cachedAccount, m);
      }

      lastRefresh = DateTime.now();
      _initSuccessful = true;
    });
  }

  bool _shouldReplaceCachedAccount(HttpCodeException error) {
    return error.code == 400 || error.code == 404;
  }

  Future<AccountState?> _resolveCachedAccount(Marker m) async {
    final preloadedAccount = _account.account;
    if (preloadedAccount != null) {
      log(m).i("using preloaded cached account");
      return preloadedAccount;
    }

    try {
      await _account.load(m);
      return _account.account;
    } catch (e) {
      final loadedAccount = _account.account;
      if (loadedAccount != null) {
        log(m).w("using cached account after load side-effect failure: $e");
        return loadedAccount;
      }
      log(m).i("cached account unavailable: $e");
      return null;
    }
  }

  // This has to be called when the account is updated in AccountStore.
  @action
  Future<void> syncAccount(AccountState? account, Marker m) async {
    return await log(m).trace("syncAccount", (m) async {
      if (account == null) return;

      final hasExp = account.jsonAccount.activeUntil != null;
      DateTime? exp = hasExp ? DateTime.parse(account.jsonAccount.activeUntil!) : null;
      expiration = expiration.update(expiration: exp);
      await _updateTimer(m);

      // Track the previous account type so that we can notice when user upgrades
      final prev = _metadata.previousAccountType;
      if (account.type.isUpgradeOver(prev)) {
        // User upgraded
        _metadata.seenExpiredDialog = false;
        await _saveMetadata(m);
      } else if (account.type == AccountType.libre && prev != AccountType.libre && prev != null) {
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
        await _updateTimer(m);
      }
    });
  }

  @action
  Future<void> onAccountExpiryEvent(Marker m) async {
    return await log(m).trace("onAccountExpiryEvent", (m) async {
      // A background FCM can land before init() ran, and the guard below must
      // not read (or save over) defaults.
      await _ensureMetadataLoaded(m);
      // Account-expiry FCM events signal that account state changed remotely.
      await _account.fetch(m);
      await syncAccount(_account.account, m);
      await _maybeShowImmediateAccountExpiryNotification(m);
    });
  }

  Future<void> _maybeShowImmediateAccountExpiryNotification(Marker m) async {
    // Leaving linked mode has to re-arm this, so never record anything here.
    if (_shouldSkipExpiryNotification()) return;

    final activeUntil = _account.account?.jsonAccount.activeUntil;
    final now = DateTime.now();
    final parsed = _parseDate(activeUntil);
    // No usable expiry means no expiry to announce.
    if (parsed == null) {
      log(m).i("accountExpiry:skipNotification:noExpiry");
      return;
    }
    // Still active, the scheduled notification owns this one.
    if (parsed.isAfter(now)) return;

    final reason = _expiryNotificationSkipReason(parsed, now);
    if (reason != null) {
      log(m).pair("skipNotification", reason);
      return;
    }

    // Claim this lapse before awaiting anything. Nothing serializes the FCM
    // handler, so a burst of pushes would otherwise all pass the check above
    // while the first one is still waiting on the channel.
    final claimed = _metadata.expiryNotifiedFor;
    _metadata.expiryNotifiedFor = parsed.toUtc().toIso8601String();
    try {
      await _notification.show(_accountExpiryNotificationId(), m);
    } catch (e) {
      // Nothing was shown, so give the claim back. Left standing it would be
      // persisted by the next _saveMetadata and silence this lapse for good.
      _metadata.expiryNotifiedFor = claimed;
      rethrow;
    }
    await _saveMetadata(m);
  }

  // One lapse gets one notification, keyed by the expiry it announces rather
  // than by when it was announced. The value is stable for a lapse and, by
  // construction, different for the next one, so nothing needs re-arming on
  // renewal and the client is indifferent to how often the server dispatches.
  String? _expiryNotificationSkipReason(DateTime expiry, DateTime now) {
    // Instants, not the raw strings: a formatting change on the server side
    // must not defeat the match.
    final notifiedFor = _parseDate(_metadata.expiryNotifiedFor);
    if (notifiedFor != null && notifiedFor.isAtSameMomentAs(expiry)) {
      return "alreadyNotified";
    }

    // The OS notification scheduled for this same expiry has just fired, so
    // announcing it again now would be the one lapse seen twice. Bounded,
    // because arming an alarm is not delivering one: Android drops pending
    // alarms on reboot and _updateTimer will not re-arm an account that has
    // already expired, which leaves this push as the only thing that can
    // announce that lapse.
    final scheduledFor = _parseDate(_metadata.expiryScheduledFor);
    if (scheduledFor != null &&
        scheduledFor.isAtSameMomentAs(expiry) &&
        now.difference(expiry) < Core.config.accountExpiryScheduledGrace) {
      return "alreadyScheduled";
    }

    return null;
  }

  Future<void> _ensureMetadataLoaded(Marker m) {
    if (_metadataLoaded) return Future.value();
    return _metadataLoading ??= _loadMetadata(m);
  }

  Future<void> _loadMetadata(Marker m) async {
    try {
      final metadataJson = await _persistence.load(m, _keyRefresh);
      // A new account may have been created while this load was in flight; its
      // fresh metadata wins over the blob we just read.
      if (_metadataLoaded) return;
      if (metadataJson != null) {
        _metadata = JsonAccRefreshMeta.fromJson(jsonDecode(metadataJson));
      }
    } catch (e) {
      // A corrupt blob must not take down the expiry event with it: start over
      // rather than throw before the account is even refreshed.
      log(m).w("could not read refresh metadata, starting fresh: $e");
      _metadata = JsonAccRefreshMeta();
    } finally {
      _metadataLoaded = true;
      _metadataLoading = null;
    }
  }

  static DateTime? _parseDate(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  NotificationId _accountExpiryNotificationId() {
    return Core.act.isFamily ? NotificationId.accountExpiredFamily : NotificationId.accountExpired;
  }

  bool _shouldSkipExpiryNotification() {
    return Core.act.isFamily && _linkedMode.now;
  }

  Future<void> _updateTimer(Marker m) async {
    final id = _accountExpiryNotificationId();
    final shouldSkipNotification = _shouldSkipExpiryNotification();

    DateTime? expDate = expiration.getNextDate();

    if (expDate != null && !shouldSkipNotification) {
      await _scheduler.addOrUpdate(Job(
        _keyTimer,
        m,
        before: expDate,
        callback: onTimerFired,
      ));

      log(m).pair("notificationId", id);
      log(m).pair("notificationDate", expiration.expiration);

      try {
        await _notification.show(id, when: expiration.expiration, m);
      } catch (e) {
        // Nothing was scheduled, so do not record one: the immediate
        // notification is the fallback for exactly this case.
        log(m).w("could not schedule expiry notification: $e");
        return;
      }

      _metadata.expiryScheduledFor = expiration.expiration.toUtc().toIso8601String();
      await _saveMetadata(m);
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
