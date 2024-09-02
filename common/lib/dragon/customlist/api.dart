import '../../common/model.dart';
import '../../util/di.dart';
import '../api/api.dart';

class CustomListApi {
  late final _api = dep<Api>();
  late final _marshal = JsonCustomListMarshal();

  Future<List<JsonCustomList>> fetchForProfile(String profileId) async {
    final response = await _api.request(
      ApiEndpoint.getCustomList,
      params: {ApiParam.profileId: profileId},
    );
    return _marshal.toCustomList(response);
  }

  add(String profileId, JsonCustomList entry) async {
    await _api.request(ApiEndpoint.postCustomList,
        payload: _marshal.fromPayload(JsonCustomListPayload.forCreate(
          profileId: profileId,
          domainName: entry.domainName,
          action: entry.action,
        )));
  }

  delete(String profileId, JsonCustomList entry) async {
    await _api.request(ApiEndpoint.deleteCustomList,
        payload: _marshal.fromPayload(JsonCustomListPayload.forDelete(
          profileId: profileId,
          domainName: entry.domainName,
        )));
  }
}
