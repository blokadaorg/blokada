import 'package:collection/collection.dart';
import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../../../timer/timer.dart';
import '../../account/account.dart';
import '../../stage/stage.dart';
import '../stats.dart';

part 'refresh.g.dart';

const String keyTimer = "stats:refresh";

class StatsRefreshStore = StatsRefreshStoreBase with _$StatsRefreshStore;

abstract class StatsRefreshStoreBase with Store, Logging, Dependable {
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

  DateTime? _getNextRefresh(Marker m) {
    if (!_accountIsActive || !_isForeground) {
      log(m)
          .i("stats: skip refresh: acc: $_accountIsActive, fg: $_isForeground");
      return null;
    } else if (_isStatsScreenFor != null) {
      return _lastRefresh.add(cfg.refreshVeryFrequent);
    } else if (_isHomeScreen) {
      return _lastRefresh.add(cfg.refreshOnHome);
    } else {
      return _lastRefresh.add(cfg.statsRefreshWhenOnAnotherScreen);
    }
  }

  _refresh(Marker m) async {
    if (act.isFamily()) {
      if (_isStatsScreenFor != null) {
        // Stats screen opened for a device, we need to refresh only that device
        log(m).pair("devices", 1);
        await _stats.fetchForDevice(_isStatsScreenFor!, m, toplists: true);
      } else {
        // Otherwise just refresh all monitored devices (less often)
        log(m).pair("devices", _monitoredDevices.length);
        for (final deviceName in _monitoredDevices) {
          await _stats.fetchForDevice(deviceName, m);
        }
      }
    } else {
      await _stats.fetch(m);
    }

    _lastRefresh = DateTime.now();
    _reschedule(m);
  }

  @action
  Future<void> setMonitoredDevices(List<String> devices, Marker m) async {
    if (const DeepCollectionEquality().equals(devices, _monitoredDevices)) {
      return;
    }

    return await log(m).trace("setMonitoredDevices", (m) async {
      log(m).pair("devices", devices);
      _monitoredDevices = devices;
      _lastRefresh = DateTime(0); // To cause one immediate refresh
      _reschedule(m);
    });
  }

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    _isForeground = route.isForeground();
    _isHomeScreen = route.isTab(StageTab.home);

    if (route.isTab(StageTab.home) && route.isSection("stats")) {
      _isStatsScreenFor = _stats.selectedDevice;
      _lastRefresh = DateTime(0); // To cause one immediate refresh
    } else {
      _isStatsScreenFor = null;
      if (route.isBecameForeground()) {
        _lastRefresh = DateTime(0); // To cause one immediate refresh
      }
    }
    _reschedule(m);
  }

  @action
  Future<void> onAccountChanged(Marker m) async {
    final account = _account.account!;
    _accountIsActive = account.type.isActive();
    _reschedule(m);
  }

  @action
  Future<void> onAccountIdChanged(Marker m) async {
    await _stats.drop(m);
  }

  _reschedule(Marker m) {
    final newDate = _getNextRefresh(m);
    if (newDate != null) {
      _timer.set(keyTimer, newDate);
    } else {
      _timer.unset(keyTimer);
    }
  }
}
