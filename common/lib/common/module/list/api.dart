part of 'list.dart';

class ListApi {
  late final _api = Core.get<Api>();

  Future<List<JsonListItem>> get(Marker m) async {
    final response = await _api.get(ApiEndpoint.getLists, m);
    return ListMarshal().lists(response);
  }
}
