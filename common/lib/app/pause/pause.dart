import 'package:common/app/pause/channel.pg.dart';
import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../account/refresh/refresh.dart';
import '../../device/device.dart';
import '../../perm/perm.dart';
import '../../stage/stage.dart';
import '../../timer/timer.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../app.dart';

part 'pause.g.dart';

const _pauseDuration = Duration(seconds: 30);
const String _keyTimer = "app:pause";

class AccountTypeException implements Exception {}

class OnboardingException implements Exception {}

class AppPauseStore = AppPauseStoreBase with _$AppPauseStore;

abstract class AppPauseStoreBase with Store, Traceable {
  late final _app = di<AppStore>();
  late final _timer = di<TimerService>();
  late final _cloud = di<DeviceStore>();
  late final _cloudPerm = di<PermStore>();
  late final _account = di<AccountStore>();
  late final _stage = di<StageStore>();

  @observable
  bool paused = false;

  @observable
  DateTime? pausedUntil;

  @action
  Future<void> pauseAppUntil(Trace parentTrace, Duration duration) async {
    return await traceWith(parentTrace, "pauseAppUntil", (trace) async {
      await _app.reconfiguring(trace);
      await _pauseApp(trace);
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
      // TODO: fix this for plus mode
      if (paused) {
        await unpauseApp(trace);
      } else {
        await pauseAppIndefinitely(trace);
      }
    });
  }

  Future<void> _pauseApp(Trace trace) async {
    await _cloud.setCloudEnabled(trace, false);
  }

  Future<void> _unpauseApp(Trace trace) async {
    if (_account.getAccountType() == AccountType.libre) {
      throw AccountTypeException();
    } else if (!_cloudPerm.isPrivateDnsEnabledFor(_cloud.deviceTag)) {
      throw OnboardingException();
    } // TODO: plus stuff
    await _cloud.setCloudEnabled(trace, true);
  }
}

class AppPauseBinder with AppPauseEvents, Traceable {
  late final _store = di<AppPauseStore>();
  late final _ops = di<AppPauseOps>();
  late final _app = di<AppStore>();
  late final _timer = di<TimerService>();
  late final _appStarter = di<AppStarter>();

  AppPauseBinder() {
    AppPauseEvents.setup(this);
    _onTimerFired();
    _onPausedUntilChange();
    _onAppStatusChange();
  }

  AppPauseBinder.forTesting() {
    _onTimerFired();
    _onPausedUntilChange();
    _onAppStatusChange();
  }

  Future<void> onStartApp() async {
    await traceAs("onStartApp", (trace) async {
      await _app.initStarted(trace);
      await _appStarter.startApp();
      await _app.initCompleted(trace);
    });
  }

  @override
  Future<void> onPauseApp(bool isIndefinitely) async {
    await traceAs("onPauseApp", (trace) async {
      if (isIndefinitely) {
        await _store.pauseAppIndefinitely(trace);
      } else {
        await _store.pauseAppUntil(trace, _pauseDuration);
      }
    });
  }

  @override
  Future<void> onUnpauseApp() async {
    await traceAs("onUnpauseApp", (trace) async {
      await _store.unpauseApp(trace);
    });
  }

  void _onTimerFired() {
    _timer.addHandler(_keyTimer, () async {
      await traceAs("onTimerFired", (trace) async {
        await _store.unpauseApp(trace);
      });
    });
  }

  void _onPausedUntilChange() {
    reactionOnStore((_) => _store.pausedUntil, (pausedUntil) async {
      await traceAs("onPausedUntilChange", (trace) async {
        final seconds = pausedUntil?.difference(DateTime.now()).inSeconds ?? 0;
        await _ops.doAppPauseDurationChanged(seconds);
      });
    });
  }

  void _onAppStatusChange() {
    reactionOnStore((_) => _app.status, (status) async {
      await traceAs("onAppStatusChangeSleazy", (trace) async {
        // Sync the state (mostly at the app start)
        // XXX: a bit sleazy
        if (status.isActive() && _store.paused) {
          _store.paused = false;
        } else if (status.isInactive() && !_store.paused) {
          _store.paused = true;
        }
      });
    });
  }
}

Future<void> init() async {
  di.registerSingleton<AppPauseOps>(AppPauseOps());
  di.registerSingleton<AppPauseStore>(AppPauseStore());
  di.registerSingleton<AppPauseBinder>(AppPauseBinder());
}
