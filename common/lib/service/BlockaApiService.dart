import 'package:common/service/Services.dart';

import '../model/BlockaModel.dart';

class BlockaApiService {

  late final _http = Services.instance.http;

  Future<StatsEndpoint> getStats(String accountId, String since, String downsample) async {
      final Map<String, dynamic> data = await _http.get("/v2/stats?account_id=$accountId&since=$since&downsample=$downsample");
      return StatsEndpoint.fromJson(data);
  }

}