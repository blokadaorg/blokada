import 'package:mobx/mobx.dart';

import '../../account/account.dart';
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
  late final _stats = di<StatsStore>();
  late final _timer = di<TimerService>();

  StatsRefreshStoreBase() {
    _timer.addHandler(keyTimer, (trace) async {
      await _stats.fetch(trace);
      await statsRefreshed(trace);
    });
  }

  @override
  attach() {
    depend<StatsRefreshStore>(this as StatsRefreshStore);
  }

  @observable
  StatsRefreshStrategy strategy = StatsRefreshStrategy.init();

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
    return await traceWith(parentTrace, "updateAccount", (trace) async {
      strategy = strategy.update(isAccountActive: isActive);
      _rescheduleTimer(trace);
    });
  }

  @action
  Future<void> statsRefreshed(Trace parentTrace) async {
    return await traceWith(parentTrace, "statsRefreshed", (trace) async {
      strategy = strategy.statsRefreshed();
      _rescheduleTimer(trace);
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

// TODO: drop all stats and refresh on account ID change

// TODO: refresh 3s after VPN settles
}
