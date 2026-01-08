import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';

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
  late int pausedForSeconds;
  late bool safeSearch;

  JsonDevice({
    required this.deviceTag,
    required this.lists,
    required this.retention,
    required this.paused,
    required this.pausedForSeconds,
    required this.safeSearch,
  });

  JsonDevice.fromJson(Map<String, dynamic> json) {
    try {
      deviceTag = json['device_tag'];
      lists = json['lists'].cast<String>();
      retention = json['retention'];
      paused = json['paused'];
      pausedForSeconds = json['paused_for'] ?? 0;
      safeSearch = json['safe_search'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonDevicePayload {
  late List<String>? lists;
  late String? retention;
  late bool? paused;
  late int? pausedForSeconds;
  late bool? safeSearch;

  JsonDevicePayload.forLists({
    required this.lists,
  })  : retention = null,
        paused = null,
        pausedForSeconds = null,
        safeSearch = null;

  JsonDevicePayload.forRetention({
    required this.retention,
  })  : lists = null,
        paused = null,
        pausedForSeconds = null,
        safeSearch = null;

  JsonDevicePayload.forPaused({
    required this.paused,
    required this.pausedForSeconds,
  })  : lists = null,
        retention = null,
        safeSearch = null;

  JsonDevicePayload.forSafeSearch({
    required this.safeSearch,
  })  : lists = null,
        retention = null,
        pausedForSeconds = null,
        paused = null;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['account_id'] = ApiParam.accountId.placeholder;
    data['lists'] = lists;
    data['retention'] = retention;
    data['paused'] = paused;
    data['paused_for'] = pausedForSeconds;
    data['safe_search'] = safeSearch;
    return data;
  }
}

class DeviceMarshal {
  JsonDevice toDevice(JsonString json) {
    return JsonDevice.fromJson(jsonDecode(json));
  }

  JsonString fromPayload(Map<String, dynamic> payload) {
    return jsonEncode(payload);
  }
}

class DeviceApi {
  late final _api = Core.get<Api>();
  late final _marshal = DeviceMarshal();

  Future<JsonDevice> getDevice(Marker m) async {
    final result = await _api.get(ApiEndpoint.getDeviceV2, m);
    return _marshal.toDevice(result);
  }

  Future<void> putDevice(
    Marker m, {
    bool? paused,
    int? pausedForSeconds,
    List<String>? lists,
    String? retention,
    bool? safeSearch,
  }) async {
    if (paused == null &&
        lists == null &&
        retention == null &&
        safeSearch == null) {
      throw ArgumentError("No argument set for putDevice");
    }

    dynamic payload = <String, dynamic>{};
    if (paused != null) {
      payload = JsonDevicePayload.forPaused(
              paused: paused, pausedForSeconds: pausedForSeconds)
          .toJson();
    } else if (lists != null) {
      payload = JsonDevicePayload.forLists(lists: lists).toJson();
    } else if (retention != null) {
      payload = JsonDevicePayload.forRetention(retention: retention).toJson();
    } else if (safeSearch != null) {
      payload =
          JsonDevicePayload.forSafeSearch(safeSearch: safeSearch).toJson();
    }

    await _api.request(ApiEndpoint.putDeviceV2, m,
        payload: _marshal.fromPayload(payload));
  }
}
