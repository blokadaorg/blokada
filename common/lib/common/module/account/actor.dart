part of 'account.dart';

// TODO: drop this legacy sync class eventually
class AccountActor with Actor {
  late final _store = Core.get<acc.AccountStore>();
  late final _accountId = Core.get<AccountId>();

  @override
  onCreate(Marker m) async {
    _store.addOn(acc.accountChanged, (m) async {
      await _accountId.change(m, _store.account!.id);
    });
  }

  @override
  onStart(Marker m) async {
    if (_store.account != null) {
      await _accountId.change(m, _store.account!.id);
    }
  }
}
