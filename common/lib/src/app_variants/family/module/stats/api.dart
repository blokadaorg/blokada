part of 'stats.dart';

class StatsApi {
  late final _api = Core.get<Api>();
  late final _accountId = Core.get<AccountId>();
  late final _marshal = JsonStatsMarshall();
  late final _platformStatsApi = Core.get<platform_stats.StatsApi>();

  Future<JsonStatsEndpoint> fetch(
      Marker m, DeviceTag tag, String since, String downsample) async {
    final response = await _api.get(ApiEndpoint.getStats, m, params: {
      ApiParam.accountId: await _accountId.now(),
      ApiParam.deviceTag: tag.toString(),
      ApiParam.statsSince: since,
      ApiParam.statsDownsample: downsample,
    });
    return _marshal.toEndpoint(response);
  }

  Future<platform_stats.JsonToplistV2Response> fetchToplist({
    required Marker m,
    required DeviceTag tag,
    String? deviceName,
    int level = 1,
    String? action,
    String? domain,
    int limit = 10,
    String range = "24h",
  }) async {
    return await _platformStatsApi.getToplistV2(
      accountId: await _accountId.now(),
      deviceTag: tag.toString(),
      deviceName: deviceName,
      level: level,
      action: action,
      domain: domain,
      limit: limit,
      range: range,
      m: m,
    );
  }
}
