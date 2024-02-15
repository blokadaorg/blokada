import 'dart:convert';

import '../../json/json.dart';
import '../api/api.dart';

class JsonDeviceEndpoint {
  late List<JsonDevice> devices;

  JsonDeviceEndpoint({required this.devices});

  JsonDeviceEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      devices = json['devices']
          .map<JsonDevice>((e) => JsonDevice.fromJson(e))
          .toList();
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonDevice {
  late String deviceTag;
  late String alias;
  late bool paused;
  late String retention;
  late String profileId;

  JsonDevice({
    required this.deviceTag,
    required this.alias,
    required this.paused,
    required this.retention,
    required this.profileId,
  });

  JsonDevice.create({
    required this.alias,
    required this.profileId,
  })  : paused = false,
        retention = '';

  JsonDevice.fromJson(Map<String, dynamic> json) {
    try {
      deviceTag = json['device_tag'];
      alias = json['alias'];
      paused = json['paused'];
      retention = json['retention'];
      profileId = json['profile_id'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['device_tag'] = deviceTag;
    map['alias'] = alias;
    map['paused'] = paused;
    map['retention'] = retention;
    map['profile_id'] = profileId;
    return map;
  }
}

class JsonDevicePayload {
  late String? deviceTag;
  late String? alias;
  late bool? paused;
  late String? retention;
  late String? profileId;

  JsonDevicePayload.forCreate({
    required this.alias,
    required this.profileId,
  })  : deviceTag = null,
        paused = null,
        retention = null,
        assert(alias != null && profileId != null);

  JsonDevicePayload.forUpdateAlias({
    required this.deviceTag,
    required this.alias,
  })  : paused = null,
        retention = null,
        profileId = null,
        assert(alias != null && deviceTag != null);

  JsonDevicePayload.forUpdateRetention({
    required this.deviceTag,
    required this.retention,
  })  : alias = null,
        paused = null,
        profileId = null,
        assert(retention != null && deviceTag != null);

  JsonDevicePayload.forUpdatePaused({
    required this.deviceTag,
    required this.paused,
  })  : alias = null,
        retention = null,
        profileId = null,
        assert(paused != null && deviceTag != null);

  JsonDevicePayload.forDelete({
    required this.deviceTag,
  })  : alias = null,
        retention = null,
        paused = null,
        profileId = null,
        assert(deviceTag != null);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['account_id'] = ApiParam.accountId.placeholder;
    if (deviceTag != null) map['device_tag'] = deviceTag;
    if (alias != null) map['alias'] = alias;
    if (paused != null) map['paused'] = paused;
    if (retention != null) map['retention'] = retention;
    if (profileId != null) map['profile_id'] = profileId;
    return map;
  }
}

class DeviceJson {
  List<JsonDevice> devices(String json) {
    return JsonDeviceEndpoint.fromJson(jsonDecode(json)).devices;
  }

  String payload(JsonDevicePayload payload) {
    return jsonEncode(payload.toJson());
  }
}
