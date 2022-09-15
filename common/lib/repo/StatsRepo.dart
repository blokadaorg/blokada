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

    List<int> hourlyAllowed = List.filled(24, 0);
    List<int> hourlyBlocked = List.filled(24, 0);

    for (var metric in stats.stats.metrics) {
      final isAllowed = metric.tags.action == "fallthrough";
      metric.dps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (var d in metric.dps) {
        final diffHours = ((now - d.timestamp) ~/ 3600);
        final hourIndex = 24 - diffHours - 1;

        if (hourIndex < 0) continue;

        if (isAllowed) {
          hourlyAllowed[hourIndex] = d.value.round();
        } else {
          hourlyBlocked[hourIndex] = d.value.round();
        }

        print(now);
        print(d.timestamp);
        print(hourIndex);
      }
    }

    print(hourlyAllowed);
    print(hourlyBlocked);

    return UiStats(
      allowed: int.parse(stats.totalAllowed),
      blocked: int.parse(stats.totalBlocked),
      hourlyAllowed: hourlyAllowed,
      hourlyBlocked: hourlyBlocked
    );
  }

}