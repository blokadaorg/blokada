part of 'account.dart';

// TODO: drop this legacy sync class eventually
class AccountActor with Actor {
  late final _store = DI.get<acc.AccountStore>();
  late final _accountId = DI.get<AccountId>();

  @override
  onStart(Marker m) async {
    if (_store.account != null) {
      _accountId.change(m, _store.account!.id);
    }

    _store.addOn(acc.accountChanged, (m) {
      _accountId.change(m, _store.account!.id);
    });
  }
}
