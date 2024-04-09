import '../../common/model.dart';
import '../../util/di.dart';
import '../api/api.dart';

class ListApi {
  late final _api = dep<Api>();

  Future<List<JsonListItem>> get() async {
    final response = await _api.get(ApiEndpoint.getLists);
    return ListMarshal().lists(response);
  }
}
