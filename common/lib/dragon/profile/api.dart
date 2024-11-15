import 'package:common/core/core.dart';

import '../../common/api/api.dart';
import '../../common/model/model.dart';

class ProfileApi {
  late final _api = dep<Api>();
  late final _marshal = JsonProfileMarshal();

  Future<List<JsonProfile>> fetch(Marker m) async {
    final response = await _api.get(ApiEndpoint.getProfiles, m);
    return _marshal.toProfiles(response);
  }

  Future<JsonProfile> add(Marker m, JsonProfilePayload p) async {
    final result = await _api.request(ApiEndpoint.postProfile, m,
        payload: _marshal.fromPayload(p));
    return _marshal.toProfile(result);
  }

  Future<JsonProfile> rename(
      Marker m, JsonProfile profile, String newName) async {
    final result = await _api.request(ApiEndpoint.putProfile, m,
        payload: _marshal.fromPayload(JsonProfilePayload.forUpdateAlias(
          profileId: profile.profileId,
          alias: generateProfileAlias(newName, profile.template),
        )));
    return _marshal.toProfile(result);
  }

  delete(Marker m, JsonProfile profile) async {
    await _api.request(ApiEndpoint.deleteProfile, m,
        payload: _marshal.fromPayload(JsonProfilePayload.forDelete(
          profileId: profile.profileId,
        )));
  }

  Future<JsonProfile> update(Marker m, JsonProfile profile) async {
    final result = await _api.request(ApiEndpoint.putProfile, m,
        payload: _marshal.fromPayload(JsonProfilePayload.forUpdateConfig(
          profileId: profile.profileId,
          lists: profile.lists,
          safeSearch: profile.safeSearch,
        )));
    return _marshal.toProfile(result);
  }
}
