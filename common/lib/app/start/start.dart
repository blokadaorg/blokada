import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../account/refresh/refresh.dart';
import '../../device/device.dart';
import '../../env/env.dart';
import '../../family/family.dart';
import '../../journal/journal.dart';
import '../../lock/lock.dart';
import '../../perm/perm.dart';
import '../../plus/keypair/keypair.dart';
import '../../plus/plus.dart';
import '../../rate/rate.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../timer/timer.dart';
import '../../tracer/tracer.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../app.dart';
import '../channel.pg.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'start.g.dart';

const String _keyTimer = "app:pause";

class AccountTypeException implements Exception {}

class OnboardingException implements Exception {}

class AppStartStore = AppStartStoreBase with _$AppStartStore;

abstract class AppStartStoreBase with Store, Traceable, Dependable {
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
  late final _tracer = dep<Tracer>();
  late final _family = dep<FamilyStore>();

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
  attach(Act act) {
    depend<AppStartOps>(getOps(act));
    depend<AppStartStore>(this as AppStartStore);
  }

  @observable
  bool paused = false;

  @observable
  DateTime? pausedUntil;

  // Order matters
  late final List<Startable> _startables = [
    _env,
    _lock,
    _device,
    _journal,
    _plusKeypair,
    _accountRefresh,
    _plus,
    _family,
    _rate,
    _tracer,
  ];

  @action
  Future<void> startApp(Trace parentTrace) async {
    await traceWith(parentTrace, "startApp", (trace) async {
      await _app.initStarted(trace);
      try {
        for (final startable in _startables) {
          await startable.start(trace);
        }
        await _app.initCompleted(trace);
      } catch (e) {
        await _app.initFail(trace);
        await _stage.showModal(trace, StageModal.accountInitFailed);
        rethrow;
      }
    });
  }

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
        await _stage.showModal(trace, StageModal.payment);
      } on OnboardingException {
        await _app.appPaused(trace, true);
        await _stage.showModal(trace, StageModal.perms);
      }
    });
  }

  @action
  Future<void> toggleApp(Trace parentTrace) async {
    return await traceWith(parentTrace, "toggleApp", (trace) async {
      if (_app.status == AppStatus.initFail) {
        await startApp(trace);
      } else if (paused) {
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
    if (_account.type == AccountType.libre) {
      throw AccountTypeException();
    } else if (!_perm.isPrivateDnsEnabledFor(_device.deviceTag)) {
      throw OnboardingException();
    } else if (_account.type == AccountType.plus && !_perm.vpnEnabled) {
      throw OnboardingException();
    }
    await _device.setCloudEnabled(trace, true);
  }
}
