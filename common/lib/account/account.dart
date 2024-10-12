import 'package:common/logger/logger.dart';
import 'package:common/util/async.dart';
import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../persistence/persistence.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/emitter.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'account.g.dart';

/// AccountStore
///
/// Manages user account. It is responsible for:
/// - loading account from cache
/// - creating new account if not existent in store
/// - refreshing account from API
/// - restoring account (from user or payment)
/// - storing account in cache on any change
///
/// It does not handle the account expiration by itself, see AccountRefreshStore.

final accountChanged = EmitterEvent<Account>("accountChanged");
final accountIdChanged = EmitterEvent<AccountId>("accountIdChanged");

const String _keyAccount = "account:jsonAccount";

typedef AccountId = String;

class AccountState {
  AccountId id;
  AccountType type;
  JsonAccount jsonAccount;

  AccountState(this.id, this.jsonAccount)
      : type = accountTypeFromName(jsonAccount.type);

  AccountState update(JsonAccount apiAccount) {
    return AccountState(id, apiAccount);
  }
}

AccountType accountTypeFromName(String? name) {
  return (name?.isEmpty ?? true)
      ? AccountType.libre
      : AccountType.values.byName(name ?? "unknown");
}

enum AccountType { libre, plus, cloud, family }

extension AccountTypeExt on AccountType {
  bool isActive() {
    return this != AccountType.libre;
  }

  bool isUpgradeOver(AccountType? other) {
    return other != null &&
            this == AccountType.plus &&
            other != AccountType.plus ||
        this == AccountType.cloud && other == AccountType.libre ||
        this == AccountType.family && other == AccountType.libre;
  }

  String toSimpleString() {
    return toString().split('.').last;
  }
}

extension AccountStateExt on AccountState {
  Account toAccount() {
    return Account(
      id: id,
      activeUntil: jsonAccount.activeUntil,
      active: jsonAccount.active,
      type: jsonAccount.type,
      paymentSource: jsonAccount.paymentSource,
    );
  }
}

class AccountNotInitialized implements Exception {}

class InvalidAccountId implements Exception {}

class AccountStore = AccountStoreBase with _$AccountStore;

abstract class AccountStoreBase with Store, Logging, Dependable, Emitter {
  late final _api = dep<AccountJson>();
  late final _ops = dep<AccountOps>();
  late final _persistence = dep<SecurePersistenceService>();
  late final _stage = dep<StageStore>();

  AccountStoreBase() {
    willAcceptOn([accountChanged, accountIdChanged]);

    reactionOnStore((_) => account, (account) async {
      if (account != null) {
        await _ops.doAccountChanged(account.toAccount());
      }
    });
  }

  @override
  attach(Act act) {
    depend<AccountOps>(getOps(act));
    depend<AccountJson>(AccountJson());
    depend<AccountStore>(this as AccountStore);
  }

  @observable
  AccountState? account;

  @computed
  String get id {
    final id = account?.id;
    if (id == null) {
      throw AccountNotInitialized();
    }
    return id;
  }

  @computed
  AccountType get type {
    final type = account?.type;
    return type ?? AccountType.libre;
  }

  AccountId? _previousAccountId;

  @action
  Future<void> load(Marker m) async {
    return await log(m).trace("load", (m) async {
      final accJson =
          await _persistence.loadOrThrow(_keyAccount, m, isBackup: true);
      final jsonAccount = JsonAccount.fromJson(accJson);
      _ensureValidAccountId(jsonAccount.id);
      await _changeAccount(AccountState(jsonAccount.id, jsonAccount), m);
    });
  }

  @action
  Future<void> create(Marker m) async {
    return await log(m).trace("create", (m) async {
      final jsonAccount = await _api.postAccount(m);
      await _persistence.save(_keyAccount, jsonAccount.toJson(), m,
          isBackup: true);
      await _changeAccount(AccountState(jsonAccount.id, jsonAccount), m);
    });
  }

  @action
  Future<void> fetch(Marker m) async {
    return await log(m).trace("fetch", (m) async {
      if (account == null) {
        throw AccountNotInitialized();
      }
      final jsonAccount = await _api.getAccount(account!.id, m);
      await _persistence.save(_keyAccount, jsonAccount.toJson(), m,
          isBackup: true);
      await _changeAccount(account!.update(jsonAccount), m);
    });
  }

  @action
  Future<void> restore(AccountId id, Marker m) async {
    return await log(m).trace("restore", (m) async {
      try {
        final sanitizedId = _sanitizeAccountId(id);
        _ensureValidAccountId(sanitizedId);
        final jsonAccount = await _api.getAccount(sanitizedId, m);
        await _persistence.save(_keyAccount, jsonAccount.toJson(), m,
            isBackup: true);
        await _changeAccount(AccountState(jsonAccount.id, jsonAccount), m);
        if (jsonAccount.isActive()) {
          await sleepAsync(const Duration(milliseconds: 500));
          await _stage.setRoute("home", m);
          await sleepAsync(const Duration(seconds: 1000));
          await _stage.setRoute("settings", m);
          await sleepAsync(const Duration(seconds: 1));
          await _stage.showModal(StageModal.accountRestoreIdOk, m);
        } else {
          await _stage.showModal(StageModal.accountRestoreIdFailed, m);
        }
      } catch (_) {
        await _stage.showModal(StageModal.accountInvalid, m);
        rethrow;
      }
    });
  }

  @action
  Future<void> propose(JsonAccount jsonAccount, Marker m) async {
    return await log(m).trace("propose", (m) async {
      _ensureValidAccountId(jsonAccount.id);
      await _persistence.save(_keyAccount, jsonAccount.toJson(), m,
          isBackup: true);
      await _changeAccount(AccountState(jsonAccount.id, jsonAccount), m);
    });
  }

  @action
  Future<void> expireOffline(Marker m) async {
    return await log(m).trace("expireOffline", (m) async {
      final jsonAccount = JsonAccount(
        id: account!.id,
        activeUntil: DateTime.now().toIso8601String(),
        active: false,
        type: AccountType.libre.name,
      );

      await _persistence.save(_keyAccount, jsonAccount.toJson(), m,
          isBackup: true);
      await _changeAccount(account!.update(jsonAccount), m);
    });
  }

  _changeAccount(AccountState account, Marker m) async {
    final oldA = this.account?.jsonAccount;
    final newA = account.jsonAccount;
    _ensureValidAccountType(newA);
    this.account = account;

    if (oldA != null) {
      if (oldA.type != newA.type || oldA.activeUntil != newA.activeUntil) {
        await emit(accountChanged, account, m);
      }
    } else {
      await emit(accountChanged, account, m);
    }

    if (_previousAccountId != null && _previousAccountId != account.id) {
      await emit(accountIdChanged, account.id, m);
    }
    _previousAccountId = account.id;
  }

  AccountId _sanitizeAccountId(AccountId id) {
    return id.toLowerCase().trim().replaceAll(RegExp(r"[^a-z\d]"), "");
  }

  void _ensureValidAccountId(String id) {
    if (id.isEmpty) throw InvalidAccountId();
  }

  void _ensureValidAccountType(JsonAccount acc) {
    final type = accountTypeFromName(acc.type);
    if (type == AccountType.family && !act.isFamily()) {
      throw InvalidAccountId();
    } else if (type == AccountType.cloud && act.isFamily()) {
      throw InvalidAccountId();
    } else if (type == AccountType.plus && act.isFamily()) {
      throw InvalidAccountId();
    }
  }
}
