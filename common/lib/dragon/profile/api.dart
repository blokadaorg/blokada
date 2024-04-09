import '../../common/model.dart';
import '../../util/di.dart';
import '../api/api.dart';

class ProfileApi {
  late final _api = dep<Api>();
  late final _marshal = JsonProfileMarshal();

  Future<List<JsonProfile>> fetch() async {
    final response = await _api.get(ApiEndpoint.getProfiles);
    return _marshal.toProfiles(response);
  }

  Future<JsonProfile> add(JsonProfilePayload p) async {
    final result = await _api.request(ApiEndpoint.postProfile,
        payload: _marshal.fromPayload(p));
    return _marshal.toProfile(result);
  }

  Future<JsonProfile> rename(JsonProfile profile, String newName) async {
    final result = await _api.request(ApiEndpoint.putProfile,
        payload: _marshal.fromPayload(JsonProfilePayload.forUpdateAlias(
          profileId: profile.profileId,
          alias: generateProfileAlias(newName, profile.template),
        )));
    return _marshal.toProfile(result);
  }

  delete(JsonProfile profile) async {
    await _api.request(ApiEndpoint.deleteProfile,
        payload: _marshal.fromPayload(JsonProfilePayload.forDelete(
          profileId: profile.profileId,
        )));
  }

  Future<JsonProfile> update(JsonProfile profile) async {
    final result = await _api.request(ApiEndpoint.putProfile,
        payload: _marshal.fromPayload(JsonProfilePayload.forUpdateConfig(
          profileId: profile.profileId,
          lists: profile.lists,
          safeSearch: profile.safeSearch,
        )));
    return _marshal.toProfile(result);
  }
}
