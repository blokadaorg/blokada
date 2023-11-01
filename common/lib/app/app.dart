import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../device/device.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/emitter.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'app.g.dart';

final appStatusChanged = EmitterEvent<AppStatus>();

extension AppStatusExt on AppStatus {
  bool isWorking() {
    return this == AppStatus.initializing || this == AppStatus.reconfiguring;
  }

  bool isActive() {
    return this == AppStatus.activatedCloud || this == AppStatus.activatedPlus;
  }

  bool isInactive() {
    return this == AppStatus.deactivated ||
        this == AppStatus.paused ||
        this == AppStatus.initFail;
  }
}

class AppStatusStrategy {
  final bool initStarted;
  final bool initFail;
  final bool initCompleted;
  final bool cloudPermEnabled;
  final bool cloudEnabled;
  final bool accountIsCloud;
  final bool accountIsPlus;
  final bool accountIsFamily;
  final bool plusPermEnabled;
  final bool plusActive;
  final bool reconfiguring;
  final bool appPaused;

  AppStatusStrategy({
    this.initStarted = false,
    this.initFail = false,
    this.initCompleted = false,
    this.cloudPermEnabled = false,
    this.cloudEnabled = false,
    this.accountIsCloud = false,
    this.accountIsPlus = false,
    this.accountIsFamily = false,
    this.plusPermEnabled = false,
    this.plusActive = false,
    this.reconfiguring = false,
    this.appPaused = false,
  });

  AppStatusStrategy update({
    bool? initStarted,
    bool? initFail,
    bool? initCompleted,
    bool? cloudPermEnabled,
    bool? cloudEnabled,
    bool? accountIsCloud,
    bool? accountIsPlus,
    bool? accountIsFamily,
    bool? plusPermEnabled,
    bool? plusActive,
    bool? reconfiguring,
    bool? appPaused,
  }) {
    return AppStatusStrategy(
      initStarted: initStarted ?? this.initStarted,
      initFail: initFail ?? this.initFail,
      initCompleted: initCompleted ?? this.initCompleted,
      cloudPermEnabled: cloudPermEnabled ?? this.cloudPermEnabled,
      cloudEnabled: cloudEnabled ?? this.cloudEnabled,
      accountIsCloud: accountIsCloud ?? this.accountIsCloud,
      accountIsPlus: accountIsPlus ?? this.accountIsPlus,
      accountIsFamily: accountIsFamily ?? this.accountIsFamily,
      plusPermEnabled: plusPermEnabled ?? this.plusPermEnabled,
      plusActive: plusActive ?? this.plusActive,
      reconfiguring: reconfiguring ?? this.reconfiguring,
      appPaused: appPaused ?? this.appPaused,
    );
  }

  AppStatus getCurrentStatus() {
    if (!initStarted) {
      return AppStatus.unknown;
    } else if (initFail) {
      return AppStatus.initFail;
    } else if (!initCompleted) {
      return AppStatus.initializing;
    } else if (reconfiguring) {
      return AppStatus.reconfiguring;
    } else if (accountIsPlus && /*plusPermEnabled &&*/ plusActive) {
      return (appPaused) ? AppStatus.deactivated : AppStatus.activatedPlus;
    } else if (accountIsCloud && cloudPermEnabled && cloudEnabled) {
      return (appPaused) ? AppStatus.deactivated : AppStatus.activatedCloud;
    } else if (accountIsFamily && cloudPermEnabled && cloudEnabled) {
      return (appPaused) ? AppStatus.deactivated : AppStatus.activatedCloud;
    } else {
      return AppStatus.deactivated;
    }
  }

  @override
  toString() {
    return "{initStarted: $initStarted, initFail: $initFail, initCompleted: $initCompleted, cloudPermEnabled: $cloudPermEnabled, cloudEnabled: $cloudEnabled, accountIsCloud: $accountIsCloud, accountIsPlus: $accountIsPlus, accountIsFamily: $accountIsFamily, plusPermEnabled: $plusPermEnabled, plusActive: $plusActive, plusReconfiguring: $reconfiguring, appPaused: $appPaused}";
  }
}

class AppStore = AppStoreBase with _$AppStore;

abstract class AppStoreBase with Store, Traceable, Dependable, Emitter {
  late final _ops = dep<AppOps>();
  late final _account = dep<AccountStore>();
  late final _stage = dep<StageStore>();
  late final _device = dep<DeviceStore>();

  AppStoreBase() {
    willAcceptOn([appStatusChanged]);

    _account.addOn(accountChanged, onAccountChanged);
    _device.addOn(deviceChanged, onDeviceChanged);

    reactionOnStore((_) => status, (status) async {
      await _ops.doAppStatusChanged(status);
    });
  }

  @override
  attach(Act act) {
    depend<AppOps>(getOps(act));
    depend<AppStore>(this as AppStore);
  }

  @observable
  AppStatus status = AppStatus.unknown;

  AppStatusStrategy _strategy = AppStatusStrategy();

  @action
  Future<void> initStarted(Trace parentTrace) async {
    return await traceWith(parentTrace, "initStarted", (trace) async {
      if (status != AppStatus.unknown && status != AppStatus.initFail) {
        throw StateError("initStarted: incorrect status: $status");
      }

      _strategy = _strategy.update(initStarted: true, initFail: false);
      await _updateStatus(trace);
    });
  }

  @action
  Future<void> initFail(Trace parentTrace) async {
    return await traceWith(parentTrace, "initFail", (trace) async {
      if (status != AppStatus.initializing) {
        throw StateError("initFail: incorrect status: $status");
      }

      _strategy = _strategy.update(initFail: true);
      await _updateStatus(trace);
    });
  }

  @action
  Future<void> initCompleted(Trace parentTrace) async {
    return await traceWith(parentTrace, "initCompleted", (trace) async {
      if (status != AppStatus.initializing) {
        throw StateError("initCompleted: incorrect status: $status");
      }

      _strategy = _strategy.update(initFail: false, initCompleted: true);
      await _updateStatus(trace);
    });
  }

  @action
  Future<void> cloudPermEnabled(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "cloudPermEnabled", (trace) async {
      _strategy = _strategy.update(cloudPermEnabled: enabled);
      await _updateStatus(trace);
    });
  }

  @action
  Future<void> onDeviceChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onDeviceChanged", (trace) async {
      final enabled = _device.cloudEnabled;
      _strategy = _strategy.update(cloudEnabled: enabled);
      await _updateStatus(trace);
    });
  }

  @action
  Future<void> onAccountChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onAccountChanged", (trace) async {
      final account = _account.account!;
      final isCloud = account.type == AccountType.cloud;
      final isPlus = account.type == AccountType.plus;
      final isFamily = account.type == AccountType.family;

      _strategy = _strategy.update(
          accountIsCloud: isCloud || isPlus,
          accountIsPlus: isPlus,
          accountIsFamily: isFamily);
      await _updateStatus(trace);
    });
  }

  @action
  Future<void> appPaused(Trace parentTrace, bool paused) async {
    return await traceWith(parentTrace, "appPaused", (trace) async {
      _strategy = _strategy.update(appPaused: paused, reconfiguring: false);
      await _updateStatus(trace);
      trace.addAttribute("paused", paused);
      trace.addAttribute("appStatusStrategy", _strategy);
      trace.addAttribute("appStatus", status);
    });
  }

  @action
  Future<void> plusActivated(Trace parentTrace, bool active) async {
    return await traceWith(parentTrace, "plusActivated", (trace) async {
      _strategy = _strategy.update(plusActive: active, reconfiguring: false);
      await _updateStatus(trace);
      trace.addAttribute("active", active);
      trace.addAttribute("appStatusStrategy", _strategy);
      trace.addAttribute("appStatus", status);
    });
  }

  @action
  Future<void> reconfiguring(Trace parentTrace) async {
    return await traceWith(parentTrace, "reconfiguring", (trace) async {
      _strategy = _strategy.update(reconfiguring: true);
      await _updateStatus(trace);
    });
  }

  _updateStatus(Trace trace) async {
    status = _strategy.getCurrentStatus();
    await _stage.setReady(
        trace, !status.isWorking() && status != AppStatus.unknown);
    await emit(appStatusChanged, trace, status);
  }
}
