part of 'account.dart';

// TODO: drop this legacy sync class eventually
class AccountActor with Actor, Logging {
  late final _store = Core.get<acc.AccountStore>();
  late final _accountId = Core.get<AccountId>();

  @override
  onCreate(Marker m) async {
    await _store.addOn(acc.accountChanged, onAccountChanged);
  }

  @override
  onStart(Marker m) async {
    if (_store.account != null) {
      await _accountId.change(m, _store.account!.id);
    }
  }

  onAccountChanged(Marker m) async {
    return await log(m).trace("onAccountChanged", (m) async {
      await _accountId.change(m, _store.account!.id);
    });
  }
}
