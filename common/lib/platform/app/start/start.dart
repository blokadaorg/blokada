import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/payment/payment.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/plus/plus.dart';
import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../device/device.dart';
import '../../perm/perm.dart';
import '../app.dart';

part 'start.g.dart';

const String _keyTimer = "app:pause";
const String _keyAutoStart = "app:autoStart";

class AccountTypeException implements Exception {}

class OnboardingException implements Exception {}

class AppStartStore = AppStartStoreBase with _$AppStartStore;

abstract class AppStartStoreBase with Store, Logging, Actor {
  late final _app = Core.get<AppStore>();
  late final _scheduler = Core.get<Scheduler>();
  late final _device = Core.get<DeviceStore>();
  late final _account = Core.get<AccountStore>();
  late final _plus = Core.get<PlusActor>();
  late final _permStore = Core.get<PlatformPermActor>();
  late final _payment = Core.get<PaymentActor>();
  late final _modal = Core.get<CurrentModalValue>();
  late final _stage = Core.get<StageStore>();

  AppStartStoreBase() {
    _app.addOn(appStatusChanged, onAppStatus);
  }

  onRegister() {
    Core.register<AppStartStore>(this as AppStartStore);
    reactionOnStore((_) => _device.pausedForSeconds, _rescheduleUnpause);
  }

  bool _paused = false;
  bool _cloudPermEnabled = false;
  bool _plusPermEnabled = false;

  @observable
  Duration? pausedFor;

  @observable
  DateTime? pausedUntil;

  @computed
  Duration? get pausedForAccurate {
    if (pausedUntil == null) return null;
    final remaining = pausedUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  _rescheduleUnpause(_) {
    if (_device.pausedForSeconds > 0) {
      pausedFor = Duration(seconds: _device.pausedForSeconds);
      pausedUntil = DateTime.now().add(pausedFor!);
      _scheduler
          .addOrUpdate(Job(_keyTimer, Markers.timer, before: pausedUntil!, callback: unpauseApp));
    } else {
      _scheduler.stop(Markers.timer, _keyTimer);
      pausedFor = null;
      pausedUntil = null;
    }
  }

  onAppStatus(Marker m) async {
    if (_app.status.isActive()) {
      _paused = false;
    } else if (_app.status.isInactive()) {
      _paused = true;
    }

    if (Core.act.isFamily) return;
    if (!_account.type.isActive()) return;

    // If cloud onboard has just changed
    if (_cloudPermEnabled != _app.conditions.cloudPermEnabled) {
      _cloudPermEnabled = _app.conditions.cloudPermEnabled;

      if (_app.conditions.cloudPermEnabled) {
        if (_device.cloudEnabled == true) {
          // Just got the perms, auto start the app
          await _scheduler.addOrUpdate(Job(_keyAutoStart, Markers.ui,
              before: DateTime.now().add(const Duration(seconds: 1)), // Wait a bit at startup
              callback: unpauseApp));
        }
      } else {
        // Just lost the perms, show the perms screen
        _modal.change(m, Modal.onboardPrivateDns);
      }
      return;
    }

    // If plus onboard has just changed
    if (_plusPermEnabled != _app.conditions.plusPermEnabled) {
      _plusPermEnabled = _app.conditions.plusPermEnabled;

      if (_app.conditions.plusPermEnabled && !_app.status.isWorking()) {
        // Just got the perms, show the location selection screen
        await log(m).trace("autoLocationAfterPerms", (m) async {
          // TODO: replace with new modal approach
          await _stage.showModal(StageModal.plusLocationSelect, m);
        });
      }
      return;
    }
  }

  @action
  Future<void> startApp(Marker m) async {
    return await log(m).trace("startApp", (m) async {
      log(m).i("Start at: ${DateTime.now()}");

      // TODO: get rid of this start procedure, we start in modules.dart now
      await _app.initStarted(m);
      await _app.initCompleted(m);
    });
  }

  @action
  Future<void> pauseAppUntil(Duration duration, Marker m) async {
    return await log(m).trace("pauseAppUntil", (m) async {
      try {
        await _app.reconfiguring(m);
        await _pauseApp(m, pauseDuration: duration);
        _paused = true;
        await _app.appPaused(true, m);
      } catch (e) {
        _paused = false;
        await _app.appPaused(false, m);
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
        _paused = true;
        await _app.appPaused(true, m);
      } catch (e) {
        _paused = false;
        await _app.appPaused(false, m);
      }
    });
  }

  @action
  Future<bool> unpauseApp(Marker m) async {
    await log(m).trace("unpauseApp", (m) async {
      try {
        pausedFor = null;
        pausedUntil = null;
        await _app.reconfiguring(m);
        await _unpauseApp(m);
        if (!Core.act.isFamily) await _plus.reactToAppPause(true, m);
        _paused = false;
        await _app.appPaused(false, m);
      } on AccountTypeException {
        try {
          await _payment.openPaymentScreen(m);

          // Delay to show in-progress until payment sheet loads
          // MARK1
          // Freemium flow works better without this delay
          if (!_app.conditions.accountIsFreemium) {
            log(m).i("Delay wait for payment screen");
            await sleepAsync(const Duration(seconds: 3));
          }
          await _app.appPaused(true, m);
        } catch (e) {
          await _app.appPaused(true, m);
          rethrow;
        }
      } on OnboardingException {
        await _app.appPaused(true, m);
        _permStore.askNotificationPermissions(m); // V6 only
        rethrow;
      } catch (e) {
        await _permStore.syncPerms(m);
        rethrow;
      }
    });
    return false;
  }

  @action
  Future<void> toggleApp(Marker m, {Duration? duration}) async {
    return await log(m).trace("toggleApp", (m) async {
      if (_app.status == AppStatus.initFail) {
        await startApp(m);
      } else if (_paused) {
        await unpauseApp(m);
      } else if (duration != null) {
        await pauseAppUntil(duration, m);
      } else {
        await pauseAppIndefinitely(m);
      }
    });
  }

  Future<void> _pauseApp(Marker m, {Duration? pauseDuration}) async {
    await _device.setCloudEnabled(m, false, pauseDuration: pauseDuration);
  }

  Future<void> _unpauseApp(Marker m) async {
    if (_account.type == AccountType.libre) {
      throw AccountTypeException();
    } else if (!_permStore.isPrivateDnsEnabledFor(_device.deviceTag)) {
      throw OnboardingException();
      // } else if (_account.type == AccountType.plus && _permVpn.present != true) {
      //   throw OnboardingException();
    }
    await _device.setCloudEnabled(m, true);
  }
}
