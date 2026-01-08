part of 'device.dart';

enum JsonDeviceMode { off, on, blocked }

extension JsonDeviceModeToString on String {
  JsonDeviceMode toMode() {
    return JsonDeviceMode.values.firstWhere(
      (e) => e.name == this,
      orElse: () => JsonDeviceMode.off,
    );
  }
}

class JsonDevice {
  late String deviceTag;
  late String alias;
  late JsonDeviceMode mode;
  late String retention;
  late String profileId;
  late String lastHeartbeat;

  JsonDevice({
    required this.deviceTag,
    required this.alias,
    required this.mode,
    required this.retention,
    required this.profileId,
  });

  JsonDevice.fromJson(Map<String, dynamic> json) {
    try {
      deviceTag = json['device_tag'];
      alias = json['alias'];
      mode = json['mode'].toString().toMode();
      retention = json['retention'];
      profileId = json['profile_id'];
      lastHeartbeat = json['last_heartbeat'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['device_tag'] = deviceTag;
    map['alias'] = alias;
    map['mode'] = mode.name;
    map['retention'] = retention;
    map['profile_id'] = profileId;
    map['last_heartbeat'] = lastHeartbeat;
    return map;
  }
}

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

class JsonDevicePayload {
  late String? deviceTag;
  late String? alias;
  late JsonDeviceMode? mode;
  late String? retention;
  late String? profileId;

  JsonDevicePayload.forCreate({
    required this.alias,
    required this.profileId,
  })  : deviceTag = null,
        mode = JsonDeviceMode.on,
        retention = "24h",
        assert(alias != null && profileId != null);

  JsonDevicePayload.forUpdateAlias({
    required this.deviceTag,
    required this.alias,
  })  : mode = null,
        retention = null,
        profileId = null,
        assert(alias != null && deviceTag != null);

  JsonDevicePayload.forUpdateRetention({
    required this.deviceTag,
    required this.retention,
  })  : alias = null,
        mode = null,
        profileId = null,
        assert(retention != null && deviceTag != null);

  JsonDevicePayload.forUpdateMode({
    required this.deviceTag,
    required JsonDeviceMode this.mode,
    this.retention,
  })  : alias = null,
        //retention = null,
        profileId = null,
        assert(deviceTag != null);

  JsonDevicePayload.forUpdateProfile({
    required this.deviceTag,
    required this.profileId,
  })  : alias = null,
        retention = null,
        mode = null,
        assert(deviceTag != null && profileId != null);

  JsonDevicePayload.forDelete({
    required this.deviceTag,
  })  : alias = null,
        retention = null,
        mode = null,
        profileId = null,
        assert(deviceTag != null);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['account_id'] = ApiParam.accountId.placeholder;
    if (deviceTag != null) map['device_tag'] = deviceTag;
    if (alias != null) map['alias'] = alias;
    if (mode != null) map['mode'] = mode!.name;
    if (retention != null) map['retention'] = retention;
    if (profileId != null) map['profile_id'] = profileId;
    return map;
  }
}

class JsonDeviceMarshal {
  List<JsonDevice> toDevices(JsonString json) {
    return JsonDeviceEndpoint.fromJson(jsonDecode(json)).devices;
  }

  JsonDevice toDevice(JsonString json) {
    return JsonDevice.fromJson(jsonDecode(json)['device']);
  }

  JsonDevice toDeviceDirect(JsonString json) {
    return JsonDevice.fromJson(jsonDecode(json));
  }

  JsonString fromDeviceDirect(JsonDevice device) {
    return jsonEncode(device.toJson());
  }

  JsonString fromPayload(JsonDevicePayload payload) {
    return jsonEncode(payload.toJson());
  }
}
