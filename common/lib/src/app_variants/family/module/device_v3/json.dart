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

  /// Schedule attached to this device. Purely additive on the wire — legacy
  /// devices simply omit this field and behave like today (top-level
  /// `profileId` is the Default). When a parent first saves a rule, the api
  /// stores the schedule and subsequent GETs include it.
  ScheduleModel? schedule;

  /// IANA timezone identifier (e.g. "Europe/Stockholm"). Carried at the
  /// device-config level (peer of `schedule`) so the resolver can compute
  /// DST correctly without depending on the app to push fresh offsets. App
  /// writes it on first schedule save and on explicit user override only —
  /// no background refresh. The api defaults to `"UTC"` on read for legacy
  /// records, but to keep the wire format additive we keep the field
  /// nullable on the client.
  String? timezone;

  JsonDevice({
    required this.deviceTag,
    required this.alias,
    required this.mode,
    required this.retention,
    required this.profileId,
    this.schedule,
    this.timezone,
  });

  JsonDevice.fromJson(Map<String, dynamic> json) {
    try {
      deviceTag = json['device_tag'];
      alias = json['alias'];
      mode = json['mode'].toString().toMode();
      retention = json['retention'];
      profileId = json['profile_id'];
      lastHeartbeat = json['last_heartbeat'];
      if (json['schedule'] is Map<String, dynamic>) {
        schedule = ScheduleModel.fromJson(json['schedule']);
      } else {
        schedule = null;
      }
      timezone = json['timezone'] as String?;
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
    if (schedule != null) map['schedule'] = schedule!.toJson();
    if (timezone != null) map['timezone'] = timezone;
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

  /// Schedule field used by [forUpdateSchedule]. The payload sends partial
  /// updates only — the api treats absent fields as "unchanged".
  late ScheduleModel? schedule;

  /// IANA timezone identifier. Populated on the same payload as `schedule`
  /// on first save (and on explicit user override). See `ScheduleActor`.
  late String? timezone;

  JsonDevicePayload.forCreate({
    required this.alias,
    required this.profileId,
  })  : deviceTag = null,
        mode = JsonDeviceMode.on,
        retention = "24h",
        schedule = null,
        timezone = null,
        assert(alias != null && profileId != null);

  JsonDevicePayload.forUpdateAlias({
    required this.deviceTag,
    required this.alias,
  })  : mode = null,
        retention = null,
        profileId = null,
        schedule = null,
        timezone = null,
        assert(alias != null && deviceTag != null);

  JsonDevicePayload.forUpdateRetention({
    required this.deviceTag,
    required this.retention,
  })  : alias = null,
        mode = null,
        profileId = null,
        schedule = null,
        timezone = null,
        assert(retention != null && deviceTag != null);

  JsonDevicePayload.forUpdateMode({
    required this.deviceTag,
    required JsonDeviceMode this.mode,
    this.retention,
  })  : alias = null,
        //retention = null,
        profileId = null,
        schedule = null,
        timezone = null,
        assert(deviceTag != null);

  JsonDevicePayload.forUpdateProfile({
    required this.deviceTag,
    required this.profileId,
  })  : alias = null,
        retention = null,
        mode = null,
        schedule = null,
        timezone = null,
        assert(deviceTag != null && profileId != null);

  /// Partial update that carries a [ScheduleModel] (and, on first save, an
  /// IANA timezone). The api PUT endpoint treats absent fields as unchanged,
  /// so this payload only writes `schedule` (+ `timezone` when supplied)
  /// and leaves alias / mode / retention / profile_id alone.
  JsonDevicePayload.forUpdateSchedule({
    required this.deviceTag,
    required ScheduleModel this.schedule,
    this.timezone,
  })  : alias = null,
        retention = null,
        mode = null,
        profileId = null,
        assert(deviceTag != null);

  JsonDevicePayload.forDelete({
    required this.deviceTag,
  })  : alias = null,
        retention = null,
        mode = null,
        profileId = null,
        schedule = null,
        timezone = null,
        assert(deviceTag != null);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['account_id'] = ApiParam.accountId.placeholder;
    if (deviceTag != null) map['device_tag'] = deviceTag;
    if (alias != null) map['alias'] = alias;
    if (mode != null) map['mode'] = mode!.name;
    if (retention != null) map['retention'] = retention;
    if (profileId != null) map['profile_id'] = profileId;
    if (schedule != null) map['schedule'] = schedule!.toJson();
    if (timezone != null) map['timezone'] = timezone;
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
