import 'package:common/core/core.dart';

import '../../common/api/api.dart';
import '../../common/model/model.dart';

class DeviceApi {
  late final _api = dep<Api>();
  late final _marshal = JsonDeviceMarshal();

  Future<List<JsonDevice>> fetch(Marker m) async {
    final response = await _api.get(ApiEndpoint.getDevices, m);
    return _marshal.toDevices(response);
  }

  Future<List<JsonDevice>> fetchByToken(
      DeviceTag tag, String token, Marker m) async {
    final response = await _api.request(
      ApiEndpoint.getDevicesByToken,
      m,
      params: {ApiParam.deviceTag: tag},
      headers: {"Authorization": "Bearer $token"},
    );
    return _marshal.toDevices(response);
  }

  Future<JsonDevice> add(JsonDevicePayload p, Marker m) async {
    final result = await _api.request(ApiEndpoint.postDevice, m,
        payload: _marshal.fromPayload(p));
    return _marshal.toDevice(result);
  }

  Future<JsonDevice> rename(JsonDevice device, String newName, Marker m) async {
    final result = await _api.request(ApiEndpoint.putDevice, m,
        payload: _marshal.fromPayload(JsonDevicePayload.forUpdateAlias(
          deviceTag: device.deviceTag,
          alias: newName,
        )));
    return _marshal.toDevice(result);
  }

  delete(JsonDevice device, Marker m) async {
    await _api.request(ApiEndpoint.deleteDevice, m,
        payload: _marshal.fromPayload(JsonDevicePayload.forDelete(
          deviceTag: device.deviceTag,
        )));
  }

  Future<JsonDevice> pause(JsonDevice device, bool paused, Marker m) async {
    final result = await _api.request(ApiEndpoint.putDevice, m,
        payload: _marshal.fromPayload(JsonDevicePayload.forUpdatePaused(
            deviceTag: device.deviceTag,
            paused: paused,
            retention: paused ? null : "24h")));
    return _marshal.toDevice(result);
  }

  Future<JsonDevice> changeProfile(
      JsonDevice device, String profileId, Marker m) async {
    final result = await _api.request(ApiEndpoint.putDevice, m,
        payload: _marshal.fromPayload(JsonDevicePayload.forUpdateProfile(
          deviceTag: device.deviceTag,
          profileId: profileId,
        )));
    return _marshal.toDevice(result);
  }
}
