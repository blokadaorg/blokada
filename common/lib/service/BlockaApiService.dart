import 'package:common/service/Services.dart';

import '../model/BlockaModel.dart';

class BlockaApiService {

  late final _http = Services.instance.http;

  Future<StatsEndpoint> getStats(String accountId) async {
      final Map<String, dynamic> data = await _http.get("/v2/stats?account_id=$accountId&since=24h");
      return StatsEndpoint.fromJson(data);
  }

}