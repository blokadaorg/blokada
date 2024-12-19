import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../device/device.dart';
import '../stage/stage.dart';

part 'app.g.dart';

final appStatusChanged = EmitterEvent<AppStatus>("appStatusChanged");

enum AppStatus {
  unknown,
  initializing,
  initFail,
  reconfiguring,
  deactivated,
  paused,
  activatedCloud,
  activatedPlus
}

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

abstract class AppStoreBase with Store, Logging, Actor, Emitter {
  late final _account = Core.get<AccountStore>();
  late final _stage = Core.get<StageStore>();
  late final _device = Core.get<DeviceStore>();

  AppStoreBase() {
    willAcceptOn([appStatusChanged]);

    _account.addOn(accountChanged, onAccountChanged);
    _device.addOn(deviceChanged, onDeviceChanged);
  }

  @override
  onRegister() {
    Core.register<AppStore>(this as AppStore);
  }

  @observable
  AppStatus status = AppStatus.unknown;

  AppStatusStrategy _strategy = AppStatusStrategy();

  @action
  Future<void> initStarted(Marker m) async {
    return await log(m).trace("initStarted", (m) async {
      if (status != AppStatus.unknown && status != AppStatus.initFail) {
        throw StateError("initStarted: incorrect status: $status");
      }

      _strategy = _strategy.update(initStarted: true, initFail: false);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> initFail(Marker m) async {
    return await log(m).trace("initFail", (m) async {
      if (status != AppStatus.initializing) {
        throw StateError("initFail: incorrect status: $status");
      }

      _strategy = _strategy.update(initFail: true);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> initCompleted(Marker m) async {
    return await log(m).trace("initCompleted", (m) async {
      if (status != AppStatus.initializing) {
        throw StateError("initCompleted: incorrect status: $status");
      }

      _strategy = _strategy.update(initFail: false, initCompleted: true);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> cloudPermEnabled(bool enabled, Marker m) async {
    return await log(m).trace("cloudPermEnabled", (m) async {
      _strategy = _strategy.update(cloudPermEnabled: enabled);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> onDeviceChanged(Marker m) async {
    return await log(m).trace("onDeviceChanged", (m) async {
      final enabled = _device.cloudEnabled;
      _strategy = _strategy.update(cloudEnabled: enabled);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> onAccountChanged(Marker m) async {
    return await log(m).trace("onAccountChanged", (m) async {
      final account = _account.account!;
      final isCloud = account.type == AccountType.cloud;
      final isPlus = account.type == AccountType.plus;
      final isFamily = account.type == AccountType.family;

      _strategy = _strategy.update(
          accountIsCloud: isCloud || isPlus,
          accountIsPlus: isPlus,
          accountIsFamily: isFamily);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> appPaused(bool paused, Marker m) async {
    return await log(m).trace("appPaused", (m) async {
      _strategy = _strategy.update(appPaused: paused, reconfiguring: false);
      await _updateStatus(m);
      log(m).pair("paused", paused);
      log(m).pair("appStatusStrategy", _strategy);
      log(m).pair("appStatus", status);
    });
  }

  @action
  Future<void> plusActivated(bool active, Marker m) async {
    return await log(m).trace("plusActivated", (m) async {
      _strategy = _strategy.update(plusActive: active, reconfiguring: false);
      await _updateStatus(m);
      log(m).pair("active", active);
      log(m).pair("appStatusStrategy", _strategy);
      log(m).pair("appStatus", status);
    });
  }

  @action
  Future<void> reconfiguring(Marker m) async {
    return await log(m).trace("reconfiguring", (m) async {
      _strategy = _strategy.update(reconfiguring: true);
      await _updateStatus(m);
    });
  }

  _updateStatus(Marker m) async {
    status = _strategy.getCurrentStatus();
    await _stage.setReady(
        !status.isWorking() && status != AppStatus.unknown, m);
    await emit(appStatusChanged, status, m);
  }
}
