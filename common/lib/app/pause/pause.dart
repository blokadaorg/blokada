import 'dart:io';

import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../device/device.dart';
import '../../perm/perm.dart';
import '../../plus/plus.dart';
import '../../stage/stage.dart';
import '../../timer/timer.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../app.dart';
import 'channel.pg.dart';

part 'pause.g.dart';

const String _keyTimer = "app:pause";

class AccountTypeException implements Exception {}

class OnboardingException implements Exception {}

class AppPauseStore = AppPauseStoreBase with _$AppPauseStore;

abstract class AppPauseStoreBase with Store, Traceable, Dependable {
  late final _ops = di<AppPauseOps>();
  late final _app = di<AppStore>();
  late final _timer = di<TimerService>();
  late final _device = di<DeviceStore>();
  late final _perm = di<PermStore>();
  late final _account = di<AccountStore>();
  late final _stage = di<StageStore>();
  late final _plus = di<PlusStore>();

  AppPauseStoreBase() {
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
  attach() {
    depend<AppPauseOps>(AppPauseOps());
    depend<AppPauseStore>(this as AppPauseStore);
  }

  @observable
  bool paused = false;

  @observable
  DateTime? pausedUntil;

  @action
  Future<void> pauseAppUntil(Trace parentTrace, Duration duration) async {
    return await traceWith(parentTrace, "pauseAppUntil", (trace) async {
      await _app.reconfiguring(trace);
      await _pauseApp(trace);
      await _plus.reactToAppPause(trace, false);
      paused = true;
      await _app.appPaused(trace, true);
      final pausedUntil = DateTime.now().add(duration);
      _timer.set(_keyTimer, pausedUntil);
      this.pausedUntil = pausedUntil;
      trace.addAttribute("pausedUntil", pausedUntil);
    }, fallback: (trace) async {
      paused = false;
      await _app.appPaused(trace, false);
      _timer.unset(_keyTimer);
      pausedUntil = null;
    });
  }

  @action
  Future<void> pauseAppIndefinitely(Trace parentTrace) async {
    return await traceWith(parentTrace, "pauseAppIndefinitely", (trace) async {
      await _app.reconfiguring(trace);
      await _pauseApp(trace);
      await _plus.reactToAppPause(trace, false);
      paused = true;
      await _app.appPaused(trace, true);
      _timer.unset(_keyTimer);
      pausedUntil = null;
    }, fallback: (trace) async {
      paused = false;
      await _app.appPaused(trace, false);
      _timer.unset(_keyTimer);
      pausedUntil = null;
    });
  }

  @action
  Future<void> unpauseApp(Trace parentTrace) async {
    return await traceWith(parentTrace, "unpauseApp", (trace) async {
      try {
        await _app.reconfiguring(trace);
        await _unpauseApp(trace);
        await _plus.reactToAppPause(trace, true);
        paused = false;
        await _app.appPaused(trace, false);
        _timer.unset(_keyTimer);
        pausedUntil = null;
      } on AccountTypeException {
        await _app.appPaused(trace, true);
        await _stage.showModalNow(trace, StageModal.payment);
      } on OnboardingException {
        await _app.appPaused(trace, true);
        await _stage.showModalNow(trace, StageModal.onboarding);
      }
    });
  }

  @action
  Future<void> toggleApp(Trace parentTrace) async {
    return await traceWith(parentTrace, "toggleApp", (trace) async {
      if (paused) {
        await unpauseApp(trace);
      } else {
        await pauseAppIndefinitely(trace);
      }
    });
  }

  Future<void> _pauseApp(Trace trace) async {
    await _device.setCloudEnabled(trace, false);
  }

  Future<void> _unpauseApp(Trace trace) async {
    if (_account.getAccountType() == AccountType.libre) {
      throw AccountTypeException();
    } else if (!_perm.isPrivateDnsEnabledFor(_device.deviceTag)) {
      throw OnboardingException();
    } else if (_account.getAccountType() == AccountType.plus &&
        !_perm.vpnEnabled) {
      throw OnboardingException();
    }
    await _device.setCloudEnabled(trace, true);
  }
}
