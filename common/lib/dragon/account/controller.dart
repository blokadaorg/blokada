import 'package:common/common/state/state.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart' as acc;

// TODO: drop this legacy sync class eventually
class AccountController {
  late final _store = DI.get<acc.AccountStore>();
  late final _accountId = DI.get<AccountId>();
  bool _started = false;

  start() async {
    if (_started) return;
    _started = true;

    if (_store.account != null) {
      _accountId.now = _store.account!.id;
    }

    _store.addOn(acc.accountChanged, (_) {
      _accountId.now = _store.account!.id;
    });
  }
}
