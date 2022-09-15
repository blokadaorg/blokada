import 'package:common/service/BlockaApiService.dart';

import '../model/UiModel.dart';

class StatsRepo {

  late final BlockaApiService _api = BlockaApiService();

  Future<UiStats> getStats(String accountId) async {
    final stats = await _api.getStats(accountId);
    return UiStats(
        allowed: int.parse(stats.totalAllowed ?? "0"),
        blocked: int.parse(stats.totalBlocked ?? "0")
    );
  }

}