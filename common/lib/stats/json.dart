import 'dart:convert';

import '../account/account.dart';
import '../http/http.dart';
import '../json/json.dart';
import '../util/di.dart';
import '../util/trace.dart';

class JsonStatsEndpoint {
  late String totalAllowed;
  late String totalBlocked;
  late JsonStats stats;

  JsonStatsEndpoint(
      {required this.totalAllowed,
      required this.totalBlocked,
      required this.stats});

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

class StatsJson {
  late final _http = dep<HttpService>();
  late final _account = dep<AccountStore>();

  Future<JsonStatsEndpoint> getStats(
      Trace trace, String since, String downsample) async {
    final data = await _http.get(trace,
        "$jsonUrl/v2/stats?account_id=${_account.id}&since=$since&downsample=$downsample");
    return JsonStatsEndpoint.fromJson(jsonDecode(data));
  }

  Future<JsonStatsEndpoint> getStatsForDevice(
      Trace trace, String since, String downsample, String deviceName) async {
    final encoded = Uri.encodeComponent(deviceName);
    final data = await _http.get(trace,
        "$jsonUrl/v2/stats?account_id=${_account.id}&since=$since&downsample=$downsample&device_name=$encoded");
    return JsonStatsEndpoint.fromJson(jsonDecode(data));
  }

  Future<JsonToplistEndpoint> getToplistForDevice(
      Trace trace, String deviceName) async {
    final encoded = Uri.encodeComponent(deviceName);
    final data = await _http.get(trace,
        "$jsonUrl/v2/activity/toplist?account_id=${_account.id}&device_name=$encoded");
    return JsonToplistEndpoint.fromJson(jsonDecode(data));
  }
}
