import 'package:collection/collection.dart';
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

class StatsRefreshStore = StatsRefreshStoreBase with _$StatsRefreshStore;

abstract class StatsRefreshStoreBase with Store, Traceable, Dependable {
  late final _stats = dep<StatsStore>();
  late final _timer = dep<TimerService>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();

  StatsRefreshStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, onAccountChanged);
    _account.addOn(accountIdChanged, onAccountIdChanged);
    _timer.addHandler(keyTimer, _refresh);
  }

  @override
  attach(Act act) {
    depend<StatsRefreshStore>(this as StatsRefreshStore);
  }

  List<String> _monitoredDevices = [];

  bool _accountIsActive = false;
  bool _isForeground = false;
  bool _isHomeScreen = false;
  String? _isStatsScreenFor;

  DateTime _lastRefresh = DateTime(0);

  DateTime? _getNextRefresh() {
    if (!_accountIsActive || !_isForeground) {
      return null;
    } else if (_isStatsScreenFor != null) {
      return _lastRefresh.add(cfg.refreshVeryFrequent);
    } else if (_isHomeScreen) {
      return _lastRefresh.add(cfg.refreshOnHome);
    } else {
      return _lastRefresh.add(cfg.statsRefreshWhenOnAnotherScreen);
    }
  }

  _refresh(Trace trace) async {
    if (act.isFamily()) {
      if (_isStatsScreenFor != null) {
        // Stats screen opened for a device, we need to refresh only that device
        trace.addAttribute("devices", 1);
        await _stats.fetchForDevice(trace, _isStatsScreenFor!, toplists: true);
      } else {
        // Otherwise just refresh all monitored devices (less often)
        trace.addAttribute("devices", _monitoredDevices.length);
        for (final deviceName in _monitoredDevices) {
          await _stats.fetchForDevice(trace, deviceName);
        }
      }
    } else {
      await _stats.fetch(trace);
    }

    _lastRefresh = DateTime.now();
  }

  @action
  Future<void> setMonitoredDevices(
      Trace parentTrace, List<String> devices) async {
    if (const DeepCollectionEquality().equals(devices, _monitoredDevices)) {
      return;
    }

    return await traceWith(parentTrace, "setMonitoredDevices", (trace) async {
      trace.addAttribute("devices", devices);
      _monitoredDevices = devices;
      _lastRefresh = DateTime(0); // To cause one immediate refresh
      _reschedule();
    });
  }

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    _isForeground = route.isForeground();
    _isHomeScreen = route.isTab(StageTab.home);

    if (route.isTab(StageTab.home) && route.isSection("stats")) {
      _isStatsScreenFor = _stats.selectedDevice;
    } else {
      _isStatsScreenFor = null;
    }
    _reschedule();
  }

  @action
  Future<void> onAccountChanged(Trace parentTrace) async {
    final account = _account.account!;
    _accountIsActive = account.type.isActive();
    _reschedule();
  }

  @action
  Future<void> onAccountIdChanged(Trace parentTrace) async {
    await _stats.drop(parentTrace);
  }

  _reschedule() {
    final newDate = _getNextRefresh();
    if (newDate != null) {
      _timer.set(keyTimer, newDate);
    } else {
      _timer.unset(keyTimer);
    }
  }
}
