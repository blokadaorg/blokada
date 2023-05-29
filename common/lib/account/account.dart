import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../persistence/persistence.dart';
import '../util/di.dart';
import '../util/trace.dart';
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

const String _keyAccount = "account:jsonAccount";

typedef AccountId = String;

class AccountState {
  AccountId id;
  AccountType type;
  JsonAccount jsonAccount;

  AccountState(this.id, this.jsonAccount)
      : type = (jsonAccount.type?.isEmpty ?? true)
            ? AccountType.libre
            : AccountType.values.byName(jsonAccount.type ?? "unknown");

  AccountState update(JsonAccount apiAccount) {
    return AccountState(id, apiAccount);
  }
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
    return this == AccountType.plus && other != AccountType.plus ||
        this == AccountType.cloud && other == AccountType.libre;
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

class AccountNotInitialized with Exception {}

class InvalidAccountId with Exception {}

class AccountStore = AccountStoreBase with _$AccountStore;

abstract class AccountStoreBase with Store, Traceable, Dependable {
  late final _api = di<AccountJson>();
  late final _ops = di<AccountOps>();
  late final _persistence = di<SecurePersistenceService>();

  AccountStoreBase() {
    reactionOnStore((_) => account, (account) async {
      if (account != null) {
        await _ops.doAccountChanged(account.toAccount());
      }
    });
  }

  @override
  attach() {
    depend<AccountJson>(AccountJson());
    depend<AccountOps>(AccountOps());
    depend<AccountStore>(this as AccountStore);
  }

  @observable
  AccountState? account;

  @action
  Future<void> load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      final accJson = await _persistence.loadOrThrow(trace, _keyAccount);
      final jsonAccount = JsonAccount.fromJson(accJson);
      _ensureValidAccountId(jsonAccount.id);
      account = AccountState(jsonAccount.id, jsonAccount);
    });
  }

  @action
  Future<void> create(Trace parentTrace) async {
    return await traceWith(parentTrace, "create", (trace) async {
      final jsonAccount = await _api.postAccount(trace);
      account = AccountState(jsonAccount.id, jsonAccount);
      await _persistence.save(trace, _keyAccount, jsonAccount.toJson());
    });
  }

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      if (account == null) {
        throw AccountNotInitialized();
      }
      final jsonAccount = await _api.getAccount(trace, account!.id);
      account = account!.update(jsonAccount);
      await _persistence.save(trace, _keyAccount, jsonAccount.toJson());
    });
  }

  @action
  Future<void> restore(Trace parentTrace, AccountId id) async {
    return await traceWith(parentTrace, "restore", (trace) async {
      final sanitizedId = _sanitizeAccountId(id);
      _ensureValidAccountId(sanitizedId);
      final jsonAccount = await _api.getAccount(trace, sanitizedId);
      account = AccountState(jsonAccount.id, jsonAccount);
      await _persistence.save(trace, _keyAccount, jsonAccount.toJson());
    });
  }

  @action
  Future<void> propose(Trace parentTrace, JsonAccount jsonAccount) async {
    return await traceWith(parentTrace, "propose", (trace) async {
      _ensureValidAccountId(jsonAccount.id);
      account = AccountState(jsonAccount.id, jsonAccount);
      await _persistence.save(trace, _keyAccount, jsonAccount.toJson());
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

      account = account!.update(jsonAccount);
      await _persistence.save(trace, _keyAccount, jsonAccount.toJson());
    });
  }

  AccountType getAccountType() {
    return account?.type ?? AccountType.libre;
  }

  AccountId _sanitizeAccountId(AccountId id) {
    return id.toLowerCase().trim().replaceAll(RegExp(r"[^a-z\d]"), "");
  }

  void _ensureValidAccountId(String id) {
    if (id.isEmpty) throw InvalidAccountId();
  }
}
