import 'package:common/common/model.dart';
import 'package:common/dragon/api/api.dart';
import 'package:common/util/di.dart';

class AuthApi {
  late final _api = dep<Api>();
  late final _marshal = JsonAuthMarshal();

  Future<JsonAuthEndpoint> auth(String accountId, DeviceTag deviceTag) async {
    final response = await _api.request(
      ApiEndpoint.postToken,
      payload: _marshal.fromPayload(
          JsonAuthPayload(accountId: accountId, deviceTag: deviceTag)),
    );
    return _marshal.toEndpoint(response);
  }

  Future<JsonAuthEndpoint> refresh(String token) async {
    final response = await _api.request(
      ApiEndpoint.postTokenRefresh,
      headers: {"Authorization": "Bearer $token"},
    );
    return _marshal.toEndpoint(response);
  }

  Future<JsonAuthEndpoint> getInfo(String token) async {
    print("getInfo token: $token");
    final response = await _api.request(
      ApiEndpoint.getTokenInfo,
      headers: {"Authorization": "Bearer $token"},
    );
    return _marshal.toEndpoint(response);
  }

  sendHeartbeat(String token) async {
    await _api.request(
      ApiEndpoint.postHeartbeat,
      headers: {"Authorization": "Bearer $token"},
    );
  }
}
