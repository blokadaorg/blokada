import 'package:common/common/value/value.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart' as acc;

// TODO: drop this legacy sync class eventually
class AccountController with Actor {
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
