import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../family/famdevice/famdevice.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../timer/timer.dart';
import '../../util/config.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../stats.dart';

part 'refresh.g.dart';

const String keyTimer = "stats:refresh";

class StatsRefreshStrategy {
  DateTime lastRefresh;
  bool isOnStatsScreen;
  bool isOnStatsHomeScreen;
  bool isForeground;
  bool isAccountActive;

  StatsRefreshStrategy({
    required this.lastRefresh,
    required this.isOnStatsScreen,
    required this.isOnStatsHomeScreen,
    required this.isForeground,
    required this.isAccountActive,
  });

  StatsRefreshStrategy.init()
      : this(
          lastRefresh: DateTime(0),
          isOnStatsScreen: false,
          isOnStatsHomeScreen: false,
          isForeground: false,
          isAccountActive: false,
        );

  StatsRefreshStrategy update({
    bool? isOnStatsScreen,
    bool? isOnStatsHomeScreen,
    bool? isForeground,
    bool? isAccountActive,
  }) {
    return StatsRefreshStrategy(
      lastRefresh: lastRefresh,
      isOnStatsScreen: isOnStatsScreen ?? this.isOnStatsScreen,
      isOnStatsHomeScreen: isOnStatsHomeScreen ?? this.isOnStatsHomeScreen,
      isForeground: isForeground ?? this.isForeground,
      isAccountActive: isAccountActive ?? this.isAccountActive,
    );
  }

  StatsRefreshStrategy statsRefreshed() {
    return StatsRefreshStrategy(
      lastRefresh: DateTime.now(),
      isOnStatsScreen: isOnStatsScreen,
      isOnStatsHomeScreen: isOnStatsHomeScreen,
      isForeground: isForeground,
      isAccountActive: isAccountActive,
    );
  }

  DateTime? getNextRefresh() {
    if (!isAccountActive || !isForeground) {
      return null;
    } else if (isOnStatsScreen) {
      return lastRefresh.add(cfg.statsRefreshWhenOnStatsScreen);
    } else if (isOnStatsHomeScreen) {
      return lastRefresh.add(cfg.statsRefreshWhenOnHomeScreen);
    } else {
      return lastRefresh.add(cfg.statsRefreshWhenOnAnotherScreen);
    }
  }
}

class StatsRefreshStore = StatsRefreshStoreBase with _$StatsRefreshStore;

abstract class StatsRefreshStoreBase with Store, Traceable, Dependable {
  late final _stats = dep<StatsStore>();
  late final _timer = dep<TimerService>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();

  late final bool _isFlavorFamily;

  StatsRefreshStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, onAccountChanged);
    _account.addOn(accountIdChanged, onAccountIdChanged);

    _timer.addHandler(keyTimer, (trace) async {
      if (_isFlavorFamily) {
        for (final deviceName in monitoredDevices) {
          await _stats.fetchForDevice(trace, deviceName);
        }
      } else {
        await _stats.fetch(trace);
      }

      await statsRefreshed(trace);
    });
  }

  @override
  attach(Act act) {
    depend<StatsRefreshStore>(this as StatsRefreshStore);
    _isFlavorFamily = act.isFamily();
  }

  @observable
  StatsRefreshStrategy strategy = StatsRefreshStrategy.init();

  @observable
  List<String> monitoredDevices = [];

  @action
  Future<void> updateForeground(Trace parentTrace, bool isForeground) async {
    return await traceWith(parentTrace, "updateForeground", (trace) async {
      strategy = strategy.update(isForeground: isForeground);
      _rescheduleTimer(trace);
    });
  }

  @action
  Future<void> updateScreen(Trace parentTrace,
      {required bool isStats, required bool isHome}) async {
    return await traceWith(parentTrace, "updateScreen", (trace) async {
      strategy = strategy.update(
          isOnStatsHomeScreen: isHome, isOnStatsScreen: isStats);
      _rescheduleTimer(trace);
    });
  }

  @action
  Future<void> updateAccount(Trace parentTrace, bool isActive) async {
    return await traceWith(parentTrace, "updateAccount", (trace) async {});
  }

  @action
  Future<void> statsRefreshed(Trace parentTrace) async {
    return await traceWith(parentTrace, "statsRefreshed", (trace) async {
      strategy = strategy.statsRefreshed();
      _rescheduleTimer(trace);
    });
  }

  @action
  Future<void> setMonitoredDevices(
      Trace parentTrace, List<String> devices) async {
    return await traceWith(parentTrace, "setMonitoredDevices", (trace) async {
      monitoredDevices = devices;
    });
  }

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    return await traceWith(parentTrace, "updateStatsRefreshFreq",
        (trace) async {
      await updateForeground(trace, route.isForeground());
      await updateScreen(
        trace,
        isHome: route.isTab(StageTab.home),
        isStats: route.isKnown(StageKnownRoute.homeStats),
      );
    });
  }

  @action
  Future<void> onAccountChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onAccountChanged", (trace) async {
      final account = _account.account!;

      final isActive = account.type.isActive();
      strategy = strategy.update(isAccountActive: isActive);
      _rescheduleTimer(trace);
    });
  }

  @action
  Future<void> onAccountIdChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onAccountIdChanged", (trace) async {
      await _stats.drop(trace);
    });
  }

  _rescheduleTimer(Trace trace) {
    // TODO: use periodic timer?
    final newDate = strategy.getNextRefresh();
    if (newDate != null) {
      _timer.set(keyTimer, newDate);
    } else {
      _timer.unset(keyTimer);
    }
  }
}
