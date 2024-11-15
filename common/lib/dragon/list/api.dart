import 'package:common/core/core.dart';

import '../../common/api/api.dart';
import '../../common/model/model.dart';

class ListApi {
  late final _api = dep<Api>();

  Future<List<JsonListItem>> get(Marker m) async {
    final response = await _api.get(ApiEndpoint.getLists, m);
    return ListMarshal().lists(response);
  }
}
