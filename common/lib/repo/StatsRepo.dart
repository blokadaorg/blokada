import 'dart:async';
import 'dart:math';
import 'package:common/repo/AppRepo.dart';
import 'package:common/repo/Repos.dart';
import 'package:mobx/mobx.dart';

import 'package:common/model/BlockaModel.dart';
import 'package:common/service/BlockaApiService.dart';

import 'package:mobx/mobx.dart' as mobx;

import '../model/UiModel.dart';
import 'AccountRepo.dart';

part 'StatsRepo.g.dart';

class StatsRepo = _StatsRepo with _$StatsRepo;

abstract class _StatsRepo with Store {

  late final BlockaApiService _api = BlockaApiService();

  late final AccountRepo accountRepo = Repos.instance.account; // TODO: CurrentUserBlockaApiService...
  late final AppRepo appRepo = Repos.instance.app;

  Timer? refreshTimer;

  @observable
  UiStats stats = UiStats.empty();

  start() async {
    _startRefreshingStats(120, true);
    _onAccountIdChanged_refreshStats();
    _onAppActivated_refreshStats();
  }

  _onAccountIdChanged_refreshStats() {
    mobx.reaction((_) => accountRepo.accountId, (_) {
      print("Account ID changed, refreshing stats");
      stats = UiStats.empty();
      _refreshStats();
    });
  }

  _onAppActivated_refreshStats() {
    mobx.reaction((_) => appRepo.appState, (_) {
      Timer(Duration(seconds: 3), () {
        // Delay to let the VPN settle
        print("App activated, refreshing stats");
        _refreshStats();
      });
    });
  }

  _startRefreshingStats(int seconds, bool refreshNow) {
    if (refreshNow) _refreshStats();
    refreshTimer = Timer.periodic(Duration(seconds: seconds), (Timer t) => _refreshStats());
  }

  _refreshStats() async {
    if (accountRepo.accountId.isEmpty) {
      print("Account ID not provided yet, skipping stats refresh");
      return;
    } else if (accountRepo.accountType == "Libre") {
      print("Libre account, skip stats refresh");
      return;
    }

    stats = await getStats(accountRepo.accountId);
  }

  _stopRefreshingStats() {
    refreshTimer?.cancel();
    refreshTimer = null;
  }

  setFrequentRefresh(bool frequent) {
    _stopRefreshingStats();
    if (frequent) {
      _startRefreshingStats(30, false);
    } else {
      _startRefreshingStats(120, false);
    }
  }

  Future<UiStats> getStats(String accountId) async {
    final oneDay = await _api.getStats(accountId, "24h", "1h");
    final oneWeek = await _api.getStats(accountId, "1w", "24h");
    return _convertStats(oneDay, oneWeek);
  }

  UiStats _convertStats(StatsEndpoint stats, StatsEndpoint oneWeek) {
    int now = DateTime.now().millisecondsSinceEpoch;
    now = now ~/ 1000; // Drop microseconds
    now = now - now % 3600; // Round down to the nearest hour

    //final rng = Random();
    //List<int> allowedHistogram = List.filled(24, rng.nextInt(500));
    List<int> allowedHistogram = List.filled(24, 0);
    List<int> blockedHistogram = List.filled(24, 0);
    int latestTimestamp = 0;

    for (var metric in stats.stats.metrics) {
      final action = metric.tags.action;
      final isAllowed = action == "fallthrough" || action == "allowed";
      metric.dps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (var d in metric.dps) {
        final diffHours = ((now - d.timestamp) ~/ 3600);
        final hourIndex = 24 - diffHours - 1;

        if (hourIndex < 0) continue;
        if (latestTimestamp < d.timestamp * 1000) latestTimestamp = d.timestamp * 1000;

        if (isAllowed) {
          allowedHistogram[hourIndex] = d.value.round();
        } else {
          blockedHistogram[hourIndex] = d.value.round();
        }
      }
    }

    print(allowedHistogram);
    print(blockedHistogram);

    // Also parse the weekly sample to get the average
    var avgDayAllowed = 0;
    var avgDayBlocked = 0;
    for (var metric in oneWeek.stats.metrics) {
      final action = metric.tags.action;
      final isAllowed = action == "fallthrough" || action == "allowed";
      metric.dps.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Get previous week if available
      if (metric.dps.length >= 2) {
        if (isAllowed) {
          avgDayAllowed = (metric.dps.sublist(0, metric.dps.length - 1).reduce((a, b) => Dps(timestamp: 0, value: a.value + b.value)).value / (metric.dps.length - 1)).round();
          avgDayAllowed = avgDayAllowed * 1;
        } else {
          avgDayBlocked = (metric.dps.sublist(0, metric.dps.length - 1).reduce((a, b) => Dps(timestamp: 0, value: a.value + b.value)).value / (metric.dps.length - 1)).round();
          avgDayBlocked = avgDayBlocked * 1;
        }
      }
    }

    if (avgDayAllowed == 0) avgDayAllowed = allowedHistogram.reduce((a, b) => a + b) * 24 ~/ 2;
    if (avgDayBlocked == 0) avgDayBlocked = blockedHistogram.reduce((a, b) => a + b) * 24 ~/ 2;
    print("daily avg: $avgDayBlocked - $avgDayAllowed");

    return UiStats(
      totalAllowed: int.parse(stats.totalAllowed),
      totalBlocked: int.parse(stats.totalBlocked),
      allowedHistogram: allowedHistogram,
      blockedHistogram: blockedHistogram,
      avgDayAllowed: avgDayAllowed, avgDayBlocked: avgDayBlocked, avgDayTotal: avgDayAllowed + avgDayBlocked,
      latestTimestamp: latestTimestamp
    );
  }

}