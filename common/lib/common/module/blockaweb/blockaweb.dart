import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/util/mobx.dart';

part 'value.dart';

class BlockaWebModule with Module {
  @override
  onCreateModule() async {
    await register(BlockaWebProvidedStatus());
    await register(BlockaWebActor());
  }
}

class BlockaWebActor with Actor, Logging {
  late final _scheduler = Core.get<Scheduler>();
  late final _app = Core.get<AppStore>();
  late final _account = Core.get<AccountEphemeral>();

  late final _status = Core.get<BlockaWebProvidedStatus>();

  DateTime _accountActiveUntil = DateTime(0);
  bool _appActive = false;

  @override
  onStart(Marker m) async {
    await _status.fetch(m);

    reactionOnStore((_) => _app.status, (retention) async {
      _appActive = _app.status.isActive();
      await _scheduleSync(m);
    });

    _account.onChangeInstant(_updateStatusFromAccount);
  }

  _updateStatusFromAccount(ValueUpdate<AccountState> it) async {
    _accountActiveUntil =
        DateTime.tryParse(it.now.jsonAccount.activeUntil ?? "") ?? DateTime(0);
    await _scheduleSync(it.m);
  }

  _scheduleSync(Marker m) async {
    await _scheduler.addOrUpdate(Job(
      "blockaweb:sync",
      m,
      before: DateTime.now(),
      callback: _syncBlockaweb,
    ));
  }

  Future<bool> _syncBlockaweb(Marker m) async {
    final newStatus = JsonBlockaweb(
      accountActiveUntil: _accountActiveUntil,
      appActive: _appActive,
    );

    await _status.change(m, newStatus);
    return false;
  }
}
