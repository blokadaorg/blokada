import 'dart:math';

import 'package:common/model/BlockaModel.dart';
import 'package:common/service/BlockaApiService.dart';

import '../model/UiModel.dart';

class StatsRepo {

  late final BlockaApiService _api = BlockaApiService();

  Future<UiStats> getStats(String accountId) async {
    final stats = await _api.getStats(accountId);
    return _convertStats(stats);
  }

  UiStats _convertStats(StatsEndpoint stats) {
    int now = DateTime.now().millisecondsSinceEpoch;
    now = now ~/ 1000; // Drop microseconds
    now = now - now % 3600; // Round down to the nearest hour

    final rng = Random();
    //List<int> allowedHistogram = List.filled(24, rng.nextInt(500));
    List<int> allowedHistogram = List.filled(24, 0);
    List<int> blockedHistogram = List.filled(24, 0);
    var hourlyAllowed = 0.0;
    var hourlyBlocked = 0.0;

    for (var metric in stats.stats.metrics) {
      final action = metric.tags.action;
      final isAllowed = action == "fallthrough" || action == "allowed";
      metric.dps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (var d in metric.dps) {
        final diffHours = ((now - d.timestamp) ~/ 3600);
        final hourIndex = 24 - diffHours - 1;

        if (hourIndex < 0) continue;

        if (isAllowed) {
          allowedHistogram[hourIndex] = d.value.round();
          hourlyAllowed += d.value;
        } else {
          blockedHistogram[hourIndex] = d.value.round();
          hourlyBlocked += d.value;
        }

        print(now);
        print(d.timestamp);
        print(hourIndex);
      }
    }

    print(allowedHistogram);
    print(blockedHistogram);

    return UiStats(
      totalAllowed: int.parse(stats.totalAllowed),
      totalBlocked: int.parse(stats.totalBlocked),
      allowedHistogram: allowedHistogram,
      blockedHistogram: blockedHistogram,
      hourlyAllowed: hourlyAllowed.round(),
      hourlyBlocked: hourlyBlocked.round()
    );
  }

}