part of 'customlist.dart';

class CustomlistApi {
  late final _api = Core.get<Api>();
  late final _marshal = JsonCustomListMarshal();

  Future<List<JsonCustomList>> fetchForProfile(Marker m,
      {String? profileId}) async {
    final endpoint = (profileId == null)
        ? ApiEndpoint.getCustomListV2
        : ApiEndpoint.getCustomList;

    final QueryParams params =
        (profileId == null) ? {} : {ApiParam.profileId: profileId};

    final response = await _api.request(endpoint, m, params: params);
    return _marshal.toCustomList(response);
  }

  add(Marker m, JsonCustomList entry, {String? profileId}) async {
    final endpoint = (profileId == null)
        ? ApiEndpoint.postCustomListV2
        : ApiEndpoint.postCustomList;

    await _api.request(endpoint, m,
        payload: _marshal.fromPayload(JsonCustomListPayload.forCreate(
          profileId: profileId,
          domainName: entry.domainName,
          action: entry.action,
        )));
  }

  delete(Marker m, JsonCustomList entry, {String? profileId}) async {
    final endpoint = (profileId == null)
        ? ApiEndpoint.deleteCustomListV2
        : ApiEndpoint.deleteCustomList;

    await _api.request(endpoint, m,
        payload: _marshal.fromPayload(JsonCustomListPayload.forDelete(
          profileId: profileId,
          domainName: entry.domainName,
        )));
  }
}
