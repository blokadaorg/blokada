import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../persistence/persistence.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/emitter.dart';
import '../util/trace.dart';
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

final accountChanged = EmitterEvent<Account>();
final accountIdChanged = EmitterEvent<AccountId>();

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

enum AccountType {
  libre,
  plus,
  cloud,
}

extension AccountTypeExt on AccountType {
  bool isActive() {
    return this != AccountType.libre;
  }

  bool isUpgradeOver(AccountType? other) {
    return other != null &&
            this == AccountType.plus &&
            other != AccountType.plus ||
        this == AccountType.cloud && other == AccountType.libre;
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

abstract class AccountStoreBase with Store, Traceable, Dependable, Emitter {
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
    if (type == null) {
      throw AccountNotInitialized();
    }
    return type;
  }

  AccountId? _previousAccountId;

  @action
  Future<void> load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      final accJson =
          await _persistence.loadOrThrow(trace, _keyAccount, isBackup: true);
      final jsonAccount = JsonAccount.fromJson(accJson);
      _ensureValidAccountId(jsonAccount.id);
      await _changeAccount(trace, AccountState(jsonAccount.id, jsonAccount));
    });
  }

  @action
  Future<void> create(Trace parentTrace) async {
    return await traceWith(parentTrace, "create", (trace) async {
      final jsonAccount = await _api.postAccount(trace);
      await _persistence.save(trace, _keyAccount, jsonAccount.toJson(),
          isBackup: true);
      await _changeAccount(trace, AccountState(jsonAccount.id, jsonAccount));
    });
  }

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      if (account == null) {
        throw AccountNotInitialized();
      }
      final jsonAccount = await _api.getAccount(trace, account!.id);
      await _persistence.save(trace, _keyAccount, jsonAccount.toJson(),
          isBackup: true);
      await _changeAccount(trace, account!.update(jsonAccount));
    });
  }

  @action
  Future<void> restore(Trace parentTrace, AccountId id) async {
    return await traceWith(parentTrace, "restore", (trace) async {
      final sanitizedId = _sanitizeAccountId(id);
      _ensureValidAccountId(sanitizedId);
      final jsonAccount = await _api.getAccount(trace, sanitizedId);
      await _persistence.save(trace, _keyAccount, jsonAccount.toJson(),
          isBackup: true);
      await _changeAccount(trace, AccountState(jsonAccount.id, jsonAccount));
      await _stage.showModal(trace, StageModal.onboarding);
    }, fallback: (trace) async {
      await _stage.showModal(trace, StageModal.accountInvalid);
    });
  }

  @action
  Future<void> propose(Trace parentTrace, JsonAccount jsonAccount) async {
    return await traceWith(parentTrace, "propose", (trace) async {
      _ensureValidAccountId(jsonAccount.id);
      await _persistence.save(trace, _keyAccount, jsonAccount.toJson(),
          isBackup: true);
      await _changeAccount(trace, AccountState(jsonAccount.id, jsonAccount));
    });
  }

  @action
  Future<void> expireOffline(Trace parentTrace) async {
    return await traceWith(parentTrace, "expireOffline", (trace) async {
      final jsonAccount = JsonAccount(
        id: account!.id,
        activeUntil: DateTime.now().toIso8601String(),
        active: false,
        type: AccountType.libre.name,
      );

      await _persistence.save(trace, _keyAccount, jsonAccount.toJson(),
          isBackup: true);
      await _changeAccount(trace, account!.update(jsonAccount));
    });
  }

  _changeAccount(Trace trace, AccountState account) async {
    final oldA = this.account?.jsonAccount;
    final newA = account.jsonAccount;
    this.account = account;
    if (oldA != null) {
      if (oldA.type != newA.type || oldA.activeUntil != newA.activeUntil) {
        await emit(accountChanged, trace, account);
      }
    } else {
      await emit(accountChanged, trace, account);
    }

    if (_previousAccountId != null && _previousAccountId != account.id) {
      await emit(accountIdChanged, trace, account.id);
    }
    _previousAccountId = account.id;
  }

  AccountId _sanitizeAccountId(AccountId id) {
    return id.toLowerCase().trim().replaceAll(RegExp(r"[^a-z\d]"), "");
  }

  void _ensureValidAccountId(String id) {
    if (id.isEmpty) throw InvalidAccountId();
  }
}
