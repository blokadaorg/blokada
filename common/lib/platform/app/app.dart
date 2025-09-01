import 'package:common/core/core.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../device/device.dart';
import 'channel.act.dart';

part 'app.g.dart';

final appStatusChanged = EmitterEvent<AppStatus>("appStatusChanged");

extension AppStatusExt on AppStatus {
  bool isWorking() {
    return this == AppStatus.initializing ||
        this == AppStatus.reconfiguring ||
        this == AppStatus.unknown;
  }

  bool isActive() {
    return this == AppStatus.activatedCloud ||
        this == AppStatus.activatedPlus ||
        this == AppStatus.activatedFreemium;
  }

  bool isInactive() {
    return this == AppStatus.deactivated ||
        this == AppStatus.paused ||
        this == AppStatus.pausedPlus ||
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
  final bool accountIsFreemium;
  final bool plusPermEnabled;
  final bool plusActive;
  final bool reconfiguring;
  final bool appPaused;
  final bool appPausedWithTimer;
  final bool freemiumEnabled;

  AppStatusStrategy({
    this.initStarted = false,
    this.initFail = false,
    this.initCompleted = false,
    this.cloudPermEnabled = false,
    this.cloudEnabled = false,
    this.accountIsCloud = false,
    this.accountIsPlus = false,
    this.accountIsFamily = false,
    this.accountIsFreemium = false,
    this.plusPermEnabled = false,
    this.plusActive = false,
    this.reconfiguring = false,
    this.appPaused = false,
    this.appPausedWithTimer = false,
    this.freemiumEnabled = false,
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
    bool? accountIsFreemium,
    bool? plusPermEnabled,
    bool? plusActive,
    bool? reconfiguring,
    bool? appPaused,
    bool? appPausedWithTimer,
    bool? freemiumEnabled,
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
      accountIsFreemium: accountIsFreemium ?? this.accountIsFreemium,
      plusPermEnabled: plusPermEnabled ?? this.plusPermEnabled,
      plusActive: plusActive ?? this.plusActive,
      reconfiguring: reconfiguring ?? this.reconfiguring,
      appPaused: appPaused ?? this.appPaused,
      appPausedWithTimer: appPausedWithTimer ?? this.appPausedWithTimer,
      freemiumEnabled: freemiumEnabled ?? this.freemiumEnabled,
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
    } else if (appPausedWithTimer && accountIsPlus) {
      return AppStatus.pausedPlus;
    } else if (accountIsPlus && plusActive) {
      return (appPaused) ? AppStatus.deactivated : AppStatus.activatedPlus;
    } else if (accountIsCloud && cloudPermEnabled && cloudEnabled) {
      return (appPaused) ? AppStatus.deactivated : AppStatus.activatedCloud;
    } else if (accountIsFamily && cloudPermEnabled && cloudEnabled) {
      return (appPaused) ? AppStatus.deactivated : AppStatus.activatedCloud;
    } else if (accountIsFreemium && freemiumEnabled) {
      return (appPaused) ? AppStatus.deactivated : AppStatus.activatedFreemium;
    } else {
      return AppStatus.deactivated;
    }
  }

  @override
  toString() {
    return "{initStarted: $initStarted, initFail: $initFail, initCompleted: $initCompleted, cloudPermEnabled: $cloudPermEnabled, cloudEnabled: $cloudEnabled, accountIsCloud: $accountIsCloud, accountIsPlus: $accountIsPlus, accountIsFamily: $accountIsFamily, accountIsFreemium: $accountIsFreemium, plusPermEnabled: $plusPermEnabled, plusActive: $plusActive, reconfiguring: $reconfiguring, appPaused: $appPaused, appPausedWithTimer: $appPausedWithTimer, freemiumEnabled: $freemiumEnabled}";
  }
}

class AppStore = AppStoreBase with _$AppStore;

abstract class AppStoreBase with Store, Logging, Actor, Emitter {
  late final _ops = Core.get<AppOps>();
  late final _account = Core.get<AccountStore>();
  late final _device = Core.get<DeviceStore>();

  AppStoreBase() {
    willAcceptOn([appStatusChanged]);

    _account.addOn(accountChanged, onAccountChanged);
    _device.addOn(deviceChanged, onDeviceChanged);

    reactionOnStore((_) => status, (status) async {
      await _ops.doAppStatusChanged(status);
    });
  }

  onRegister() {
    Core.register<AppOps>(getOps());
    Core.register<AppStore>(this as AppStore);
  }

  @observable
  AppStatus status = AppStatus.unknown;

  AppStatusStrategy conditions = AppStatusStrategy();
  bool? _pendingPlusActive;

  @action
  Future<void> initStarted(Marker m) async {
    return await log(m).trace("initStarted", (m) async {
      if (status != AppStatus.unknown && status != AppStatus.initFail) {
        throw StateError("initStarted: incorrect status: $status");
      }

      conditions = conditions.update(initStarted: true, initFail: false);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> initFail(Marker m) async {
    return await log(m).trace("initFail", (m) async {
      if (status != AppStatus.initializing) {
        throw StateError("initFail: incorrect status: $status");
      }

      conditions = conditions.update(initFail: true);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> initCompleted(Marker m) async {
    return await log(m).trace("initCompleted", (m) async {
      if (status != AppStatus.initializing) {
        throw StateError("initCompleted: incorrect status: $status");
      }

      conditions = conditions.update(initFail: false, initCompleted: true);

      // Apply any pending VPN status
      if (_pendingPlusActive != null) {
        log(m).i("Applying pending VPN status: $_pendingPlusActive");
        conditions = conditions.update(plusActive: _pendingPlusActive!, reconfiguring: false);
        _pendingPlusActive = null;
      }

      await _updateStatus(m);
    });
  }

  @action
  Future<void> cloudPermEnabled(Marker m, bool enabled) async {
    return await log(m).trace("cloudPermEnabled", (m) async {
      conditions = conditions.update(cloudPermEnabled: enabled);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> plusPermEnabled(bool enabled, Marker m) async {
    return await log(m).trace("plusPermEnabled", (m) async {
      conditions = conditions.update(plusPermEnabled: enabled);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> onDeviceChanged(Marker m) async {
    return await log(m).trace("onDeviceChanged", (m) async {
      final enabled = _device.cloudEnabled;
      conditions = conditions.update(
          cloudEnabled: enabled, appPausedWithTimer: _device.pausedForSeconds > 0);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> onAccountChanged(Marker m) async {
    return await log(m).trace("onAccountChangedUpdateAppStore", (m) async {
      final account = _account.account!;
      final isCloud = account.type == AccountType.cloud;
      final isPlus = account.type == AccountType.plus;
      final isFamily = account.type == AccountType.family;
      final isFreemium = _account.isFreemium;

      conditions = conditions.update(
        accountIsCloud: isCloud || isPlus,
        accountIsPlus: isPlus,
        accountIsFamily: isFamily,
        accountIsFreemium: isFreemium,
      );
      await _updateStatus(m);
    });
  }

  @action
  Future<void> appPaused(bool paused, Marker m) async {
    return await log(m).trace("appPaused", (m) async {
      conditions = conditions.update(appPaused: paused, reconfiguring: false);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> plusActivated(bool active, Marker m) async {
    return await log(m).trace("plusActivated", (m) async {
      if (!conditions.initStarted || !conditions.initCompleted) {
        log(m).i("Storing VPN status for after initialization");
        _pendingPlusActive = active;
        return;
      }

      conditions = conditions.update(plusActive: active, reconfiguring: false);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> freemiumActivated(Marker m, bool active) async {
    return await log(m).trace("freemiumActivated", (m) async {
      conditions = conditions.update(freemiumEnabled: active, reconfiguring: false);
      await _updateStatus(m);
    });
  }

  @action
  Future<void> reconfiguring(Marker m) async {
    return await log(m).trace("reconfiguring", (m) async {
      conditions = conditions.update(reconfiguring: true);
      await _updateStatus(m);
    });
  }

  _updateStatus(Marker m) async {
    status = conditions.getCurrentStatus();
    log(m).pair("appStatusStrategy", conditions);
    log(m).pair("appStatus", status);
    await emit(appStatusChanged, status, m);
  }
}
