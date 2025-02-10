import 'package:common/core/core.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/plus/plus.dart';
import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../account/refresh/refresh.dart';
import '../../device/device.dart';
import '../../perm/perm.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../app.dart';

part 'start.g.dart';

const String _keyTimer = "app:pause";

class AccountTypeException implements Exception {}

class OnboardingException implements Exception {}

class AppStartStore = AppStartStoreBase with _$AppStartStore;

abstract class AppStartStoreBase with Store, Logging, Actor {
  late final _app = Core.get<AppStore>();
  late final _scheduler = Core.get<Scheduler>();
  late final _device = Core.get<DeviceStore>();
  late final _perm = Core.get<PlatformPermActor>();
  late final _account = Core.get<AccountStore>();
  late final _accountRefresh = Core.get<AccountRefreshStore>();
  late final _stage = Core.get<StageStore>();
  late final _plus = Core.get<PlusActor>();
  late final _permStore = Core.get<PlatformPermActor>();

  AppStartStoreBase() {
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
  onRegister() {
    Core.register<AppStartStore>(this as AppStartStore);
  }

  @observable
  bool paused = false;

  @observable
  DateTime? pausedUntil;

  // Order matters
  late final List<Actor> _startablesV6 = [
    _device,
  ];

  late final List<Actor> _startablesFamily = [
    _device,
  ];

  @action
  Future<void> startApp(Marker m) async {
    return await log(m).trace("startApp", (m) async {
      log(m).i("Start at: ${DateTime.now()}");

      await _app.initStarted(m);
      try {
        final startables =
            Core.act.isFamily ? _startablesFamily : _startablesV6;
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
        if (!Core.act.isFamily) await _plus.reactToAppPause(false, m);
        paused = true;
        await _app.appPaused(true, m);
        final pausedUntil = DateTime.now().add(duration);
        await _scheduler.addOrUpdate(
            Job(_keyTimer, m, before: pausedUntil, callback: unpauseApp));
        this.pausedUntil = pausedUntil;
        log(m).pair("pausedUntil", pausedUntil);
      } catch (e) {
        paused = false;
        await _app.appPaused(false, m);
        await _scheduler.stop(m, _keyTimer);
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
        if (!Core.act.isFamily) await _plus.reactToAppPause(false, m);
        paused = true;
        await _app.appPaused(true, m);
        await _scheduler.stop(m, _keyTimer);
        pausedUntil = null;
      } catch (e) {
        paused = false;
        await _app.appPaused(false, m);
        await _scheduler.stop(m, _keyTimer);
        pausedUntil = null;
      }
    });
  }

  @action
  Future<bool> unpauseApp(Marker m) async {
    await log(m).trace("unpauseApp", (m) async {
      try {
        await _app.reconfiguring(m);
        await _unpauseApp(m);
        if (!Core.act.isFamily) await _plus.reactToAppPause(true, m);
        paused = false;
        await _app.appPaused(false, m);
        await _scheduler.stop(m, _keyTimer);
        pausedUntil = null;
      } on AccountTypeException {
        await _app.appPaused(true, m);
        _permStore.askNotificationPermissions(m);
        await _stage.showModal(StageModal.payment, m);
      } on OnboardingException {
        await _app.appPaused(true, m);
        _permStore.askNotificationPermissions(m);
        rethrow;
      } catch (e) {
        await _permStore.syncPerms(m);
        rethrow;
      }
    });
    return false;
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
      // } else if (_account.type == AccountType.plus && _permVpn.present != true) {
      //   throw OnboardingException();
    }
    await _device.setCloudEnabled(true, m);
  }
}
