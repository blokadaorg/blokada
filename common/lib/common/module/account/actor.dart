part of 'account.dart';

// TODO: drop this legacy sync class eventually
class AccountActor with Actor, Logging {
  late final _store = Core.get<acc.AccountStore>();
  late final _accountId = Core.get<AccountId>();
  late final _account = Core.get<AccountEphemeral>();

  @override
  onCreate(Marker m) async {
    _store.addOn(acc.accountChanged, onAccountChanged);
  }

  @override
  onStart(Marker m) async {
    if (_store.account != null) {
      await _accountId.change(m, _store.account!.id);
      await _account.change(m, _store.account!);
    }
  }

  onAccountChanged(Marker m) async {
    return await log(m).trace("onAccountChanged", (m) async {
      await _accountId.change(m, _store.account!.id);
      await _account.change(m, _store.account!);
    });
  }
}
