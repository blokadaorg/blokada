import 'dart:async';
import 'dart:math';
import 'package:common/repo/AppRepo.dart';
import 'package:common/repo/Repos.dart';
import 'package:common/repo/StageRepo.dart';
import 'package:mobx/mobx.dart';

import 'package:common/model/BlockaModel.dart';
import 'package:common/service/BlockaApiService.dart';

import 'package:mobx/mobx.dart' as mobx;

import '../model/UiModel.dart';
import '../service/Services.dart';
import 'AccountRepo.dart';

part 'StatsRepo.g.dart';

class StatsRepo = _StatsRepo with _$StatsRepo;

abstract class _StatsRepo with Store {

  late final BlockaApiService _api = BlockaApiService();
  late final log = Services.instance.log;

  late final AccountRepo accountRepo = Repos.instance.account; // TODO: CurrentUserBlockaApiService...
  late final AppRepo appRepo = Repos.instance.app;
  late final StageRepo stageRepo = Repos.instance.stage;

  Timer? refreshTimer;

  @observable
  UiStats stats = UiStats.empty();

  @observable
  bool hasStats = false;

  start() async {
    _onAppStage_manageAutoRefresh();
    _onAccountIdChanged_refreshStats();
    _onAppActivated_refreshStats();
  }

  _onAppStage_manageAutoRefresh() {
    mobx.reaction((_) => stageRepo.isForeground, (_) {
      if (stageRepo.isForeground) {
        _startRefreshingStats(120, true);
      } else {
        _stopRefreshingStats();
      }
    });
  }

  _onAccountIdChanged_refreshStats() {
    mobx.reaction((_) => accountRepo.accountId, (_) {
      log.v("Account ID changed, refreshing stats");
      stats = UiStats.empty();
      hasStats = false;
      _refreshStats();
    });
  }

  _onAppActivated_refreshStats() {
    mobx.reaction((_) => appRepo.appState, (_) {
      Timer(Duration(seconds: 3), () {
        // Delay to let the VPN settle
        log.v("App activated, refreshing stats");
        _refreshStats();
      });
    });
  }

  _startRefreshingStats(int seconds, bool refreshNow) {
    log.v("Start refreshing stats, now every $seconds seconds");
    if (refreshNow) _refreshStats();
    refreshTimer = Timer.periodic(Duration(seconds: seconds), (Timer t) => _refreshStats());
  }

  _refreshStats() async {
    if (accountRepo.accountId.isEmpty) {
      log.v("Account ID not provided yet, skipping stats refresh");
      return;
    } else if (accountRepo.accountType == "Libre") {
      log.v("Libre account, skip stats refresh");
      return;
    }

    stats = await getStats(accountRepo.accountId);
    hasStats = true;
  }

  _stopRefreshingStats() {
    log.v("Stopping refreshing stats");
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

    // Also parse the weekly sample to get the average
    var avgDayAllowed = 0;
    var avgDayBlocked = 0;
    for (var metric in oneWeek.stats.metrics) {
      final action = metric.tags.action;
      final isAllowed = action == "fallthrough" || action == "allowed";
      metric.dps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final histogram = metric.dps.map((d) => d.value.round()).toList();

      // Get previous week if available
      if (histogram.length >= 2) {
        if (isAllowed) {
          avgDayAllowed = (histogram.sublist(0, histogram.length - 1).reduce((a, b) => a + b) / (histogram.length - 1)).round();
          avgDayAllowed *= 2;
        } else {
          avgDayBlocked = (histogram.sublist(0, histogram.length - 1).reduce((a, b) => a + b) / (histogram.length - 1)).round();
          avgDayBlocked *= 2;
        }
      }
    }

    // Calculate last week's average based on this week (no data)
    if (avgDayAllowed == 0) avgDayAllowed = allowedHistogram.reduce((a, b) => a + b) * 24 * 2;
    if (avgDayBlocked == 0) avgDayBlocked = blockedHistogram.reduce((a, b) => a + b) * 24 * 2;
    log.v("daily avg: $avgDayBlocked - $avgDayAllowed");

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