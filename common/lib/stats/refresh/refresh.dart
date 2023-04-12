import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../stage/stage.dart';
import '../../timer/timer.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../stats.dart';

part 'refresh.g.dart';

const Duration _whenOnStatsScreen = Duration(seconds: 30);
const Duration _whenOnHomeScreen = Duration(seconds: 120);
const Duration _whenOnAnotherScreen = Duration(seconds: 240);

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

  StatsRefreshStrategy.init() : this(
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
      return lastRefresh.add(_whenOnStatsScreen);
    } else if (isOnStatsHomeScreen) {
      return lastRefresh.add(_whenOnHomeScreen);
    } else {
      return lastRefresh.add(_whenOnAnotherScreen);
    }
  }
}

class StatsRefreshStore = StatsRefreshStoreBase with _$StatsRefreshStore;
abstract class StatsRefreshStoreBase with Store, Traceable {
  late final _timer = di<TimerService>();

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
      { required bool isStats, required bool isHome }
  ) async {
    return await traceWith(parentTrace, "updateScreen", (trace) async {
      strategy = strategy.update(isOnStatsHomeScreen: isHome, isOnStatsScreen: isStats);
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

class StatsRefreshBinder with Traceable {
  late final _store = di<StatsRefreshStore>();
  late final _timer = di<TimerService>();
  late final _stats = di<StatsStore>();
  late final _account = di<AccountStore>();
  late final _stage = di<StageStore>();

  StatsRefreshBinder() {
    _onTimerFired();
    _onForeground();
    _onTabChange();
    _onAccountChange();
  }

  _onTimerFired() {
    _timer.addHandler(keyTimer, () async {
      await traceAs("onTimerFired", (trace) async {
        await _stats.fetch(trace);
        await _store.statsRefreshed(trace);
      });
    });
  }

  // When not in foreground, stats don't refresh
  _onForeground() {
    reaction((_) => _stage.isForeground, (isForeground) async {
      await traceAs("onForeground", (trace) async {
        await _store.updateForeground(trace, isForeground);
      });
    });
  }

  // Stats refresh more often on the Home tab
  _onTabChange() {
    autorun((_) async {
      final tab = _stage.activeTab;
      await traceAs("onTabChange", (trace) async {
        await _store.updateScreen(trace,
            isHome: tab == StageTab.home,
            isStats: false // TODO
        );
      });
    });
  }

  _onAccountChange() {
    reaction((_) => _account.account, (acc) async {
      if (acc != null) {
        await traceAs("onAccountChange", (trace) async {
          await _store.updateAccount(trace, acc.type.isActive());
        });
      }
    });
  }
}

Future<void> init() async {
  di.registerSingleton(StatsRefreshStore());
  StatsRefreshBinder();
}
