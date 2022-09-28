import 'dart:async';
import 'dart:math';
import 'package:mobx/mobx.dart';

import 'package:common/model/BlockaModel.dart';
import 'package:common/service/BlockaApiService.dart';

import '../model/UiModel.dart';

part 'StatsRepo.g.dart';

class StatsRepo = _StatsRepo with _$StatsRepo;

abstract class _StatsRepo with Store {

  late final BlockaApiService _api = BlockaApiService();
  Timer? refreshTimer;

  @observable
  UiStats stats = UiStats.empty();

  start() async {
    _startRefreshingStats(120, true);
  }

  _startRefreshingStats(int seconds, bool refreshNow) {
    if (refreshNow) _refreshStats();
    refreshTimer = Timer.periodic(Duration(seconds: seconds), (Timer t) => _refreshStats());
  }

  _refreshStats() async {
    stats = await getStats("ebwkrlznagkw");
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
    final stats = await _api.getStats(accountId);
    return _convertStats(stats);
  }

  UiStats _convertStats(StatsEndpoint stats) {
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

    return UiStats(
      totalAllowed: int.parse(stats.totalAllowed),
      totalBlocked: int.parse(stats.totalBlocked),
      allowedHistogram: allowedHistogram,
      blockedHistogram: blockedHistogram,
      latestTimestamp: latestTimestamp
    );
  }

}