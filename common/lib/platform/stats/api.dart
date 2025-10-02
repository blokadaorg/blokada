import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';

class JsonStatsEndpoint {
  late String totalAllowed;
  late String totalBlocked;
  late JsonStats stats;

  JsonStatsEndpoint({required this.totalAllowed, required this.totalBlocked, required this.stats});

  JsonStatsEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      totalAllowed = json['total_allowed'];
      totalBlocked = json['total_blocked'];
      stats = JsonStats.fromJson(json['stats']);
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_allowed'] = totalAllowed;
    data['total_blocked'] = totalBlocked;
    data['stats'] = stats.toJson();
    return data;
  }
}

class JsonStats {
  late List<JsonMetrics> metrics;

  JsonStats({required this.metrics});

  JsonStats.fromJson(Map<String, dynamic> json) {
    metrics = <JsonMetrics>[];
    json['metrics'].forEach((v) {
      metrics.add(JsonMetrics.fromJson(v));
    });
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['metrics'] = metrics.map((v) => v.toJson()).toList();
    return data;
  }
}

class JsonMetrics {
  late JsonTags tags;
  late List<JsonDps> dps;

  JsonMetrics({required this.tags, required this.dps});

  JsonMetrics.fromJson(Map<String, dynamic> json) {
    tags = JsonTags.fromJson(json['tags']);
    dps = <JsonDps>[];
    json['dps'].forEach((v) {
      dps.add(JsonDps.fromJson(v));
    });
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['tags'] = tags.toJson();
    data['dps'] = dps.map((v) => v.toJson()).toList();
    return data;
  }
}

class JsonTags {
  late String action;
  String? deviceName;
  String? company;
  String? tld;

  JsonTags({required this.action, this.deviceName, this.company, this.tld});

  JsonTags.fromJson(Map<String, dynamic> json) {
    action = json['action'];
    deviceName = json.containsKey('device_name') ? json['device_name'] : null;
    company = json.containsKey('company') ? json['company'] : null;
    tld = json.containsKey('tld') ? json['tld'] : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['action'] = action;
    data['device_name'] = deviceName;
    data['company'] = company;
    data['tld'] = tld;
    return data;
  }
}

class JsonDps {
  late int timestamp;
  late double value;

  JsonDps({required this.timestamp, required this.value});

  JsonDps.fromJson(Map<String, dynamic> json) {
    timestamp = int.parse(json['timestamp']);
    value = double.parse(json['value'].toString());
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['timestamp'] = timestamp;
    data['value'] = value;
    return data;
  }
}

class JsonToplistEndpoint {
  late JsonStats toplist;

  JsonToplistEndpoint({required this.toplist});

  JsonToplistEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      toplist = JsonStats.fromJson(json['toplist']);
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['toplist'] = toplist.toJson();
    return data;
  }
}

class StatsMarshal {
  JsonStatsEndpoint toStatsEndpoint(JsonString json) {
    return JsonStatsEndpoint.fromJson(jsonDecode(json));
  }

  JsonToplistEndpoint toToplistEndpoint(JsonString json) {
    return JsonToplistEndpoint.fromJson(jsonDecode(json));
  }
}

class StatsApi {
  late final _api = Core.get<Api>();
  late final _marshal = StatsMarshal();

  Future<JsonStatsEndpoint> getStats(String since, String downsample, Marker m) async {
    final result = await _api.get(ApiEndpoint.getStatsV2, m, params: {
      ApiParam.statsSince: since,
      ApiParam.statsDownsample: downsample,
    });

    return _marshal.toStatsEndpoint(result);
  }

  Future<JsonStatsEndpoint> getStatsForDevice(
      String since, String downsample, String deviceName, Marker m) async {
    final encoded = Uri.encodeComponent(deviceName);

    final result = await _api.get(ApiEndpoint.getStatsV2, m, params: {
      ApiParam.statsSince: since,
      ApiParam.statsDownsample: downsample,
      ApiParam.statsDeviceName: encoded,
    });

    return _marshal.toStatsEndpoint(result);
  }

  Future<JsonToplistEndpoint> getToplist(bool blocked, Marker m) async {
    // MOCK: Temporarily return mock data instead of API call
    return _getMockToplist(blocked);

    // final action = blocked ? "blocked" : "allowed";
    // final result = await _api.get(ApiEndpoint.getToplistV2V6, m, params: {
    //   ApiParam.toplistAction: action,
    // });
    // return _marshal.toToplistEndpoint(result);
  }

  Future<JsonToplistEndpoint> getToplistForDevice(bool blocked, String deviceName, Marker m) async {
    // MOCK: Temporarily return mock data instead of API call
    return _getMockToplist(blocked);

    // final action = blocked ? "blocked" : "allowed";
    // final encoded = Uri.encodeComponent(deviceName);
    // final result = await _api.get(ApiEndpoint.getToplistV2, m, params: {
    //   ApiParam.toplistAction: action,
    //   ApiParam.statsDeviceName: encoded,
    // });
    // return _marshal.toToplistEndpoint(result);
  }

  // MOCK: Helper function to generate mock toplist data
  JsonToplistEndpoint _getMockToplist(bool blocked) {
    if (blocked) {
      return JsonToplistEndpoint(
        toplist: JsonStats(
          metrics: [
            JsonMetrics(
              tags: JsonTags(action: 'blocked', company: 'doubleclick.net', tld: 'doubleclick.net'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 1250)],
            ),
            JsonMetrics(
              tags: JsonTags(action: 'blocked', company: 'facebook.com', tld: 'facebook.com'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 980)],
            ),
            JsonMetrics(
              tags: JsonTags(action: 'blocked', company: 'ads.amazon.com', tld: 'ads.amazon.com'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 750)],
            ),
            JsonMetrics(
              tags: JsonTags(action: 'blocked', company: 'analytics.microsoft.com', tld: 'analytics.microsoft.com'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 620)],
            ),
            JsonMetrics(
              tags: JsonTags(action: 'blocked', company: 'analytics.twitter.com', tld: 'analytics.twitter.com'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 500)],
            ),
          ],
        ),
      );
    } else {
      return JsonToplistEndpoint(
        toplist: JsonStats(
          metrics: [
            JsonMetrics(
              tags: JsonTags(action: 'allowed', company: 'cloudflare.com', tld: 'cloudflare.com'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 2100)],
            ),
            JsonMetrics(
              tags: JsonTags(action: 'allowed', company: 'googleapis.com', tld: 'googleapis.com'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 1800)],
            ),
            JsonMetrics(
              tags: JsonTags(action: 'allowed', company: 'apple.com', tld: 'apple.com'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 1500)],
            ),
            JsonMetrics(
              tags: JsonTags(action: 'allowed', company: 'github.com', tld: 'github.com'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 1200)],
            ),
            JsonMetrics(
              tags: JsonTags(action: 'allowed', company: 'amazonaws.com', tld: 'amazonaws.com'),
              dps: [JsonDps(timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, value: 900)],
            ),
          ],
        ),
      );
    }
  }
}
