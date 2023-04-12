import 'dart:convert';

import '../env/env.dart';
import '../http/http.dart';
import '../json/json.dart';
import '../util/di.dart';
import '../util/trace.dart';

class JsonDeviceEndpoint {
  late JsonDevice device;

  JsonDeviceEndpoint({required this.device});

  JsonDeviceEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      device = JsonDevice.fromJson(json['device']);
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonDevice {
  late String deviceTag;
  late List<String> lists;
  late String retention;
  late bool paused;

  JsonDevice(
      {required this.deviceTag,
      required this.lists,
      required this.retention,
      required this.paused});

  JsonDevice.fromJson(Map<String, dynamic> json) {
    try {
      deviceTag = json['device_tag'];
      lists = json['lists'].cast<String>();
      retention = json['retention'];
      paused = json['paused'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonDevicePayload {
  late String accountId;
  late List<String>? lists;
  late String? retention;
  late bool? paused;

  JsonDevicePayload.forLists({
    required this.accountId,
    required this.lists,
  })  : retention = null,
        paused = null;

  JsonDevicePayload.forRetention({
    required this.accountId,
    required this.retention,
  })  : lists = null,
        paused = null;

  JsonDevicePayload.forPaused({
    required this.accountId,
    required this.paused,
  })  : lists = null,
        retention = null;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['account_id'] = accountId;
    data['lists'] = lists;
    data['retention'] = retention;
    data['paused'] = paused;
    return data;
  }
}

class DeviceJson {
  late final _http = di<HttpService>();
  late final _env = di<EnvStore>();

  Future<JsonDevice> getDevice(Trace trace) async {
    final data = await _http.get(
        trace, "$jsonUrl/v2/device?account_id=${_env.currentUser}");
    return JsonDevice.fromJson(jsonDecode(data));
  }

  Future<void> putDevice(Trace trace,
      {bool? paused, List<String>? lists, String? retention}) async {
    if (paused == null && lists == null && retention == null) {
      throw ArgumentError("No argument set for putDevice");
    }

    dynamic payload = <String, dynamic>{};
    if (paused != null) {
      payload = JsonDevicePayload.forPaused(
              accountId: _env.currentUser, paused: paused)
          .toJson();
    } else if (lists != null) {
      payload =
          JsonDevicePayload.forLists(accountId: _env.currentUser, lists: lists)
              .toJson();
    } else if (retention != null) {
      payload = JsonDevicePayload.forRetention(
              accountId: _env.currentUser, retention: retention)
          .toJson();
    }

    await _http.request(trace,
        "$jsonUrl/v2/device?account_id=${_env.currentUser}", HttpType.put,
        payload: jsonEncode(payload));
  }
}
