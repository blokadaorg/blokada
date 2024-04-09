import '../../common/model.dart';
import '../../util/di.dart';
import '../api/api.dart';

class DeviceApi {
  late final _api = dep<Api>();
  late final _marshal = JsonDeviceMarshal();

  Future<List<JsonDevice>> fetch() async {
    final response = await _api.get(ApiEndpoint.getDevices);
    return _marshal.toDevices(response);
  }

  Future<List<JsonDevice>> fetchByToken(DeviceTag tag, String token) async {
    final response = await _api.request(
      ApiEndpoint.getDevicesByToken,
      params: {ApiParam.deviceTag: tag},
      headers: {"Authorization": "Bearer $token"},
    );
    return _marshal.toDevices(response);
  }

  Future<JsonDevice> add(JsonDevicePayload p) async {
    final result = await _api.request(ApiEndpoint.postDevice,
        payload: _marshal.fromPayload(p));
    return _marshal.toDevice(result);
  }

  Future<JsonDevice> rename(JsonDevice device, String newName) async {
    final result = await _api.request(ApiEndpoint.putDevice,
        payload: _marshal.fromPayload(JsonDevicePayload.forUpdateAlias(
          deviceTag: device.deviceTag,
          alias: newName,
        )));
    return _marshal.toDevice(result);
  }

  delete(JsonDevice device) async {
    await _api.request(ApiEndpoint.deleteDevice,
        payload: _marshal.fromPayload(JsonDevicePayload.forDelete(
          deviceTag: device.deviceTag,
        )));
  }

  Future<JsonDevice> pause(JsonDevice device, bool paused) async {
    final result = await _api.request(ApiEndpoint.putDevice,
        payload: _marshal.fromPayload(JsonDevicePayload.forUpdatePaused(
            deviceTag: device.deviceTag,
            paused: paused,
            retention: paused ? null : "24h")));
    return _marshal.toDevice(result);
  }

  Future<JsonDevice> changeProfile(JsonDevice device, String profileId) async {
    final result = await _api.request(ApiEndpoint.putDevice,
        payload: _marshal.fromPayload(JsonDevicePayload.forUpdateProfile(
          deviceTag: device.deviceTag,
          profileId: profileId,
        )));
    return _marshal.toDevice(result);
  }
}
