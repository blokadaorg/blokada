import 'package:common/util/mobx.dart';
import 'package:mobx/mobx.dart';

import '../event.dart';
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
  final bool plusActive;
  final bool reconfiguring;
  final bool appPaused;

  AppStatusStrategy({
    this.initStarted = false,
    this.initCompleted = false,
    this.cloudPermEnabled = false,
    this.cloudEnabled = false,
    this.accountIsCloud = false,
    this.accountIsPlus = false,
    this.plusPermEnabled = false,
    this.plusActive = false,
    this.reconfiguring = false,
    this.appPaused = false,
  });

  AppStatusStrategy update({
    bool? initStarted,
    bool? initCompleted,
    bool? cloudPermEnabled,
    bool? cloudEnabled,
    bool? accountIsCloud,
    bool? accountIsPlus,
    bool? plusPermEnabled,
    bool? plusActive,
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
      plusActive: plusActive ?? this.plusActive,
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
    } else if (accountIsPlus && /*plusPermEnabled &&*/ plusActive) {
      return (appPaused) ? AppStatus.paused : AppStatus.activatedPlus;
    } else if (accountIsCloud && cloudPermEnabled && cloudEnabled) {
      return (appPaused) ? AppStatus.paused : AppStatus.activatedCloud;
    } else {
      return AppStatus.deactivated;
    }
  }

  @override
  toString() {
    return "{initStarted: $initStarted, initCompleted: $initCompleted, cloudPermEnabled: $cloudPermEnabled, cloudEnabled: $cloudEnabled, accountIsCloud: $accountIsCloud, accountIsPlus: $accountIsPlus, plusPermEnabled: $plusPermEnabled, plusActive: $plusActive, plusReconfiguring: $reconfiguring, appPaused: $appPaused}";
  }
}

class AppStore = AppStoreBase with _$AppStore;

abstract class AppStoreBase with Store, Traceable, Dependable {
  late final _ops = di<AppOps>();
  late final _event = di<EventBus>();

  AppStoreBase() {
    reactionOnStore((_) => status, (status) async {
      await _ops.doAppStatusChanged(status);
    });
  }

  @override
  attach() {
    depend<AppOps>(AppOps());
    depend<AppStore>(this as AppStore);
  }

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
      await _updateStatus(trace);
    });
  }

  @action
  Future<void> initCompleted(Trace parentTrace) async {
    return await traceWith(parentTrace, "initCompleted", (trace) async {
      if (status != AppStatus.initializing) {
        throw StateError("initCompleted: incorrect status: $status");
      }

      _strategy = _strategy.update(initCompleted: true);
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
  Future<void> cloudEnabled(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "cloudEnabled", (trace) async {
      _strategy = _strategy.update(cloudEnabled: enabled);
      await _updateStatus(trace);
    });
  }

  @action
  Future<void> accountUpdated(Trace parentTrace,
      {required bool isCloud, required bool isPlus}) async {
    return await traceWith(parentTrace, "accountUpdated", (trace) async {
      _strategy = _strategy.update(
          accountIsCloud: isCloud || isPlus, accountIsPlus: isPlus);
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
    await _event.onEvent(trace, CommonEvent.appStatusChanged);
  }
}
