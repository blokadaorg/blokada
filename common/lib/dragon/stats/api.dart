import 'package:common/common/model.dart';
import 'package:common/dragon/account/account_id.dart';
import 'package:common/dragon/api/api.dart';
import 'package:common/logger/logger.dart';
import 'package:common/util/di.dart';

class StatsApi {
  late final _api = dep<Api>();
  late final _accountId = dep<AccountId>();
  late final _marshal = JsonStatsMarshall();

  Future<JsonStatsEndpoint> fetch(
      Marker m, DeviceTag tag, String since, String downsample) async {
    final response = await _api.get(ApiEndpoint.getStats, m, params: {
      ApiParam.accountId: _accountId.now,
      ApiParam.deviceTag: tag.toString(),
      ApiParam.statsSince: since,
      ApiParam.statsDownsample: downsample,
    });
    return _marshal.toEndpoint(response);
  }
}
