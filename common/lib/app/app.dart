import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../device/device.dart';
import '../perm/perm.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'channel.pg.dart';

part 'app.g.dart';

extension AppStatusExt on AppStatus {
  bool isWorking() {
    return this == AppStatus.initializing || this == AppStatus.reconfiguring;
  }

  bool isActive() {
    return this == AppStatus.activatedCloud || this == AppStatus.activatedPlus;
  }

  bool isInactive() {
    return this == AppStatus.deactivated || this == AppStatus.paused;
  }
}

class AppStatusStrategy {
  final bool initStarted;
  final bool initCompleted;
  final bool cloudPermEnabled;
  final bool cloudEnabled;
  final bool accountIsCloud;
  final bool accountIsPlus;
  final bool plusPermEnabled;
  final bool plusEnabled;
  final bool reconfiguring;
  final bool appPaused;

  AppStatusStrategy(
      {this.initStarted = false,
      this.initCompleted = false,
      this.cloudPermEnabled = false,
      this.cloudEnabled = false,
      this.accountIsCloud = false,
      this.accountIsPlus = false,
      this.plusPermEnabled = false,
      this.plusEnabled = false,
      this.reconfiguring = false,
      this.appPaused = false});

  AppStatusStrategy update({
    bool? initStarted,
    bool? initCompleted,
    bool? cloudPermEnabled,
    bool? cloudEnabled,
    bool? accountIsCloud,
    bool? accountIsPlus,
    bool? plusPermEnabled,
    bool? plusEnabled,
    bool? reconfiguring,
    bool? appPaused,
  }) {
    return AppStatusStrategy(
      initStarted: initStarted ?? this.initStarted,
      initCompleted: initCompleted ?? this.initCompleted,
      cloudPermEnabled: cloudPermEnabled ?? this.cloudPermEnabled,
      cloudEnabled: cloudEnabled ?? this.cloudEnabled,
      accountIsCloud: accountIsCloud ?? this.accountIsCloud,
      accountIsPlus: accountIsPlus ?? this.accountIsPlus,
      plusPermEnabled: plusPermEnabled ?? this.plusPermEnabled,
      plusEnabled: plusEnabled ?? this.plusEnabled,
      reconfiguring: reconfiguring ?? this.reconfiguring,
      appPaused: appPaused ?? this.appPaused,
    );
  }

  AppStatus getCurrentStatus() {
    if (!initStarted) {
      return AppStatus.unknown;
    } else if (!initCompleted) {
      return AppStatus.initializing;
    } else if (reconfiguring) {
      return AppStatus.reconfiguring;
    } else if (accountIsPlus && plusPermEnabled && plusEnabled) {
      return (appPaused) ? AppStatus.paused : AppStatus.activatedPlus;
    } else if (accountIsCloud && cloudPermEnabled && cloudEnabled) {
      return (appPaused) ? AppStatus.paused : AppStatus.activatedCloud;
    } else {
      return AppStatus.deactivated;
    }
  }

  @override
  toString() {
    return "{initStarted: $initStarted, initCompleted: $initCompleted, cloudPermEnabled: $cloudPermEnabled, cloudEnabled: $cloudEnabled, accountIsCloud: $accountIsCloud, accountIsPlus: $accountIsPlus, plusPermEnabled: $plusPermEnabled, plusEnabled: $plusEnabled, plusReconfiguring: $reconfiguring, appPaused: $appPaused}";
  }
}

class AppStore = AppStoreBase with _$AppStore;

abstract class AppStoreBase with Store, Traceable {
  @observable
  AppStatus status = AppStatus.unknown;

  AppStatusStrategy _strategy = AppStatusStrategy();

  @action
  Future<void> initStarted(Trace parentTrace) async {
    return await traceWith(parentTrace, "initStarted", (trace) async {
      if (status != AppStatus.unknown) {
        throw StateError("initStarted: incorrect status: $status");
      }

      _strategy = _strategy.update(initStarted: true);
      status = _strategy.getCurrentStatus();
    });
  }

  @action
  Future<void> initCompleted(Trace parentTrace) async {
    return await traceWith(parentTrace, "initCompleted", (trace) async {
      if (status != AppStatus.initializing) {
        throw StateError("initCompleted: incorrect status: $status");
      }

      _strategy = _strategy.update(initCompleted: true);
      status = _strategy.getCurrentStatus();
    });
  }

  @action
  Future<void> cloudPermEnabled(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "cloudPermEnabled", (trace) async {
      _strategy = _strategy.update(cloudPermEnabled: enabled);
      status = _strategy.getCurrentStatus();
    });
  }

  @action
  Future<void> cloudEnabled(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "cloudEnabled", (trace) async {
      _strategy = _strategy.update(cloudEnabled: enabled);
      status = _strategy.getCurrentStatus();
    });
  }

  @action
  Future<void> accountUpdated(Trace parentTrace,
      {required bool isCloud, required bool isPlus}) async {
    return await traceWith(parentTrace, "accountUpdated", (trace) async {
      _strategy = _strategy.update(
          accountIsCloud: isCloud || isPlus, accountIsPlus: isPlus);
      status = _strategy.getCurrentStatus();
    });
  }

  @action
  Future<void> appPaused(Trace parentTrace, bool paused) async {
    return await traceWith(parentTrace, "appPaused", (trace) async {
      _strategy = _strategy.update(appPaused: paused, reconfiguring: false);
      status = _strategy.getCurrentStatus();
      trace.addAttribute("paused", paused);
      trace.addAttribute("appStatusStrategy", _strategy);
      trace.addAttribute("appStatus", status);
    });
  }

  @action
  Future<void> reconfiguring(Trace parentTrace) async {
    return await traceWith(parentTrace, "reconfiguring", (trace) async {
      _strategy = _strategy.update(reconfiguring: true);
      status = _strategy.getCurrentStatus();
    });
  }
}

class AppBinder with Traceable {
  late final _store = di<AppStore>();
  late final _ops = di<AppOps>();
  late final _device = di<DeviceStore>();
  late final _perm = di<PermStore>();
  late final _account = di<AccountStore>();
  late final _stage = di<StageStore>();

  AppBinder() {
    _onAppStatus();
    _onPermStatus();
    _onDeviceEnabled();
    _onAccountUpdated();
  }

  void _onAppStatus() {
    reactionOnStore((_) => _store.status, (status) async {
      await traceAs("onAppStatus", (trace) async {
        await _stage.setReady(trace, !status.isWorking());
        await _ops.doAppStatusChanged(status);
        trace.addAttribute("appStatus", status);
      });
    });
  }

  void _onPermStatus() {
    reactionOnStore((_) => _perm.privateDnsEnabled, (permEnabled) async {
      await traceAs("onCloudPermStatus", (trace) async {
        await _store.cloudPermEnabled(trace, permEnabled == _device.deviceTag);
      });
    });
  }

  void _onDeviceEnabled() {
    reactionOnStore((_) => _device.cloudEnabled, (enabled) async {
      if (enabled != null) {
        await traceAs("onCloudEnabled", (trace) async {
          await _store.cloudEnabled(trace, enabled);
        });
      }
    });
  }

  void _onAccountUpdated() {
    reactionOnStore((_) => _account.account, (account) async {
      if (account != null) {
        await traceAs("onAccountUpdated", (trace) async {
          await _store.accountUpdated(
            trace,
            isCloud: account.type == AccountType.cloud,
            isPlus: account.type == AccountType.plus,
          );
        });
      }
    });
  }
}

Future<void> init() async {
  di.registerSingleton<AppOps>(AppOps());
  di.registerSingleton<AppStore>(AppStore());
  AppBinder();
}
