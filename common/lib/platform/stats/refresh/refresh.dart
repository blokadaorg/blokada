import 'package:collection/collection.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../stage/stage.dart';
import '../stats.dart';

part 'refresh.g.dart';

const String keyTimer = "stats:refresh";

class StatsRefreshStore = StatsRefreshStoreBase with _$StatsRefreshStore;

abstract class StatsRefreshStoreBase with Store, Logging, Actor {
  late final _stats = Core.get<StatsStore>();
  late final _stage = Core.get<StageStore>();
  late final _scheduler = Core.get<Scheduler>();
  late final _account = Core.get<AccountStore>();
  late final _journal = Core.get<JournalActor>();

  StatsRefreshStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, onAccountChanged);
    _account.addOn(accountIdChanged, onAccountIdChanged);
  }

  onRegister() {
    Core.register<StatsRefreshStore>(this as StatsRefreshStore);
  }

  List<String> _monitoredDevices = [];

  bool _accountIsActive = false;
  bool _isHomeScreen = false;
  String? _isStatsScreenFor;

  DateTime _lastRefresh = DateTime(0);

  DateTime? _getNextRefresh(Marker m) {
    if (!_accountIsActive) {
      log(m).i("stats: skip refresh: acc: $_accountIsActive");
      return null;
    } else if (_isStatsScreenFor != null) {
      return _lastRefresh.add(Core.config.refreshVeryFrequent);
    } else if (_isHomeScreen) {
      return _lastRefresh.add(Core.config.refreshOnHome);
    } else {
      return _lastRefresh.add(Core.config.statsRefreshWhenOnAnotherScreen);
    }
  }

  Future<bool> _refresh(Marker m) async {
    if (Core.act.isFamily) {
      if (_isStatsScreenFor != null) {
        // Stats screen opened for a device, we need to refresh only that device
        log(m).pair("devices", 1);
        await _stats.fetchForDevice(_isStatsScreenFor!, m);
      } else {
        // Otherwise just refresh all monitored devices (less often)
        log(m).pair("devices", _monitoredDevices.length);
        for (final deviceName in _monitoredDevices) {
          await _stats.fetchForDevice(deviceName, m);
        }
      }
    } else {
      // V6 app - refresh stats and journal (recent activity)
      // Note: toplists are NOT refreshed here to avoid excessive API calls
      // Users can manually pull-to-refresh to update toplists
      await _stats.fetch(m);
      await _journal.fetch(m, tag: null);
    }

    _lastRefresh = DateTime.now();
    _reschedule(m);
    return false;
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
    // Allow stats for active accounts OR freemium accounts (for sample data)
    _accountIsActive = account.type.isActive() || _account.isFreemium;
    log(m).t("statsRefresh, account is active: $_accountIsActive, freemium: ${_account.isFreemium}");
    _reschedule(m);
  }

  @action
  Future<void> onAccountIdChanged(Marker m) async {
    await _stats.drop(m);
  }

  _reschedule(Marker m) {
    var newDate = _getNextRefresh(m);
    if (newDate == null) {
      _scheduler.stop(m, keyTimer);
    } else {
      // Make sure first call happens in the future
      // Otherwise in onboarding we make it when stats are 0 yet
      if (newDate.isBefore(DateTime.now())) {
        newDate = DateTime.now().add(const Duration(seconds: 3));
      }

      _scheduler.addOrUpdate(Job(
        keyTimer,
        m,
        before: newDate,
        when: [Conditions.foreground],
        callback: _refresh,
      ));
    }
  }
}
