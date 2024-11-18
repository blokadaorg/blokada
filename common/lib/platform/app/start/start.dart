import 'package:common/core/core.dart';
import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../../../dragon/family/family.dart';
import '../../../lock/lock.dart';
import '../../../timer/timer.dart';
import '../../account/account.dart';
import '../../account/refresh/refresh.dart';
import '../../device/device.dart';
import '../../env/env.dart';
import '../../journal/journal.dart';
import '../../link/link.dart';
import '../../perm/perm.dart';
import '../../plus/keypair/keypair.dart';
import '../../plus/plus.dart';
import '../../rate/rate.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../app.dart';
import '../channel.pg.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'start.g.dart';

const String _keyTimer = "app:pause";

class AccountTypeException implements Exception {}

class OnboardingException implements Exception {}

class AppStartStore = AppStartStoreBase with _$AppStartStore;

abstract class AppStartStoreBase with Store, Logging, Actor {
  late final _ops = dep<AppStartOps>();

  late final _env = dep<EnvStore>();
  late final _lock = dep<LockStore>();
  late final _app = dep<AppStore>();
  late final _timer = dep<TimerService>();
  late final _device = dep<DeviceStore>();
  late final _perm = dep<PermStore>();
  late final _account = dep<AccountStore>();
  late final _accountRefresh = dep<AccountRefreshStore>();
  late final _stage = dep<StageStore>();
  late final _journal = dep<JournalStore>();
  late final _plus = dep<PlusStore>();
  late final _plusKeypair = dep<PlusKeypairStore>();
  late final _rate = dep<RateStore>();
  late final _family = dep<FamilyStore>();
  late final _link = dep<LinkStore>();

  AppStartStoreBase() {
    _timer.addHandler(_keyTimer, unpauseApp);

    reactionOnStore((_) => pausedUntil, (pausedUntil) async {
      final seconds = pausedUntil?.difference(DateTime.now()).inSeconds ?? 0;
      await _ops.doAppPauseDurationChanged(seconds);
    });

    reactionOnStore((_) => _app.status, (status) async {
      // XXX: a bit sleazy
      if (status.isActive() && paused) {
        paused = false;
      } else if (status.isInactive() && !paused) {
        paused = true;
      }
    });
  }

  @override
  onRegister(Act act) {
    depend<AppStartOps>(getOps(act));
    depend<AppStartStore>(this as AppStartStore);
  }

  @observable
  bool paused = false;

  @observable
  DateTime? pausedUntil;

  // Order matters
  late final List<Actor> _startablesV6 = [
    _env,
    _link,
    _lock,
    _device,
    _journal,
    _plusKeypair,
    _accountRefresh,
    _plus,
    _rate,
  ];

  late final List<Actor> _startablesFamily = [
    _env,
    _link,
    _lock,
    _device,
    _accountRefresh,
    _family,
    _rate,
  ];

  @action
  Future<void> startApp(Marker m) async {
    return await log(m).trace("startApp", (m) async {
      log(m).i("Start at: ${DateTime.now()}");

      await _app.initStarted(m);
      try {
        final startables = act.isFamily ? _startablesFamily : _startablesV6;
        for (final startable in startables) {
          log(m).i("starting ${startable.runtimeType}");
          await startable.start(m);
          log(m).i("started ${startable.runtimeType}");
        }
        await _app.initCompleted(m);
      } catch (e) {
        await _app.initFail(m);
        await _stage.showModal(StageModal.accountInitFailed, m);
        rethrow;
      }
    });
  }

  @action
  Future<void> pauseAppUntil(Duration duration, Marker m) async {
    return await log(m).trace("pauseAppUntil", (m) async {
      try {
        await _app.reconfiguring(m);
        await _pauseApp(m);
        if (!act.isFamily) await _plus.reactToAppPause(false, m);
        paused = true;
        await _app.appPaused(true, m);
        final pausedUntil = DateTime.now().add(duration);
        _timer.set(_keyTimer, pausedUntil);
        this.pausedUntil = pausedUntil;
        log(m).pair("pausedUntil", pausedUntil);
      } catch (e) {
        paused = false;
        await _app.appPaused(false, m);
        _timer.unset(_keyTimer);
        pausedUntil = null;
      }
    });
  }

  @action
  Future<void> pauseAppIndefinitely(Marker m) async {
    return await log(m).trace("pauseAppIndefinitely", (m) async {
      try {
        await _app.reconfiguring(m);
        await _pauseApp(m);
        if (!act.isFamily) await _plus.reactToAppPause(false, m);
        paused = true;
        await _app.appPaused(true, m);
        _timer.unset(_keyTimer);
        pausedUntil = null;
      } catch (e) {
        paused = false;
        await _app.appPaused(false, m);
        _timer.unset(_keyTimer);
        pausedUntil = null;
      }
    });
  }

  @action
  Future<void> unpauseApp(Marker m) async {
    return await log(m).trace("unpauseApp", (m) async {
      try {
        await _app.reconfiguring(m);
        await _unpauseApp(m);
        if (!act.isFamily) await _plus.reactToAppPause(true, m);
        paused = false;
        await _app.appPaused(false, m);
        _timer.unset(_keyTimer);
        pausedUntil = null;
      } on AccountTypeException {
        await _app.appPaused(true, m);
        await _stage.showModal(StageModal.payment, m);
      } on OnboardingException {
        await _app.appPaused(true, m);
        await _stage.showModal(StageModal.perms, m);
      }
    });
  }

  @action
  Future<void> toggleApp(Marker m) async {
    return await log(m).trace("toggleApp", (m) async {
      if (_app.status == AppStatus.initFail) {
        await startApp(m);
      } else if (paused) {
        await unpauseApp(m);
      } else {
        await pauseAppIndefinitely(m);
      }
    });
  }

  Future<void> _pauseApp(Marker m) async {
    await _device.setCloudEnabled(false, m);
  }

  Future<void> _unpauseApp(Marker m) async {
    if (_account.type == AccountType.libre) {
      throw AccountTypeException();
    } else if (!_perm.isPrivateDnsEnabledFor(_device.deviceTag)) {
      throw OnboardingException();
    } else if (_account.type == AccountType.plus && !_perm.vpnEnabled) {
      throw OnboardingException();
    }
    await _device.setCloudEnabled(true, m);
  }
}
