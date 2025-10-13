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
    if (json['metrics'] != null) {
      json['metrics'].forEach((v) {
        metrics.add(JsonMetrics.fromJson(v));
      });
    }
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
    if (json['dps'] != null) {
      json['dps'].forEach((v) {
        dps.add(JsonDps.fromJson(v));
      });
    }
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

// New v2 toplist models
class JsonToplistV2Response {
  late List<JsonToplistBucket> toplist;
  late JsonWindow window;
  late String level;
  String? domain;
  late int limit;

  JsonToplistV2Response({
    required this.toplist,
    required this.window,
    required this.level,
    this.domain,
    required this.limit,
  });

  JsonToplistV2Response.fromJson(Map<String, dynamic> json) {
    try {
      toplist = <JsonToplistBucket>[];
      if (json['toplist'] != null) {
        json['toplist'].forEach((v) {
          toplist.add(JsonToplistBucket.fromJson(v));
        });
      }
      window = JsonWindow.fromJson(json['window']);
      level = json['level'];
      domain = json.containsKey('domain') ? json['domain'] : null;
      limit = json['limit'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['toplist'] = toplist.map((v) => v.toJson()).toList();
    data['window'] = window.toJson();
    data['level'] = level;
    if (domain != null) data['domain'] = domain;
    data['limit'] = limit;
    return data;
  }
}

class JsonToplistBucket {
  late String action;
  int? parentCount;
  late List<JsonToplistEntry> entries;

  JsonToplistBucket({required this.action, this.parentCount, required this.entries});

  JsonToplistBucket.fromJson(Map<String, dynamic> json) {
    action = json['action'];
    parentCount = json.containsKey('parent_count') ? json['parent_count'] : null;
    entries = <JsonToplistEntry>[];
    if (json['entries'] != null) {
      json['entries'].forEach((v) {
        entries.add(JsonToplistEntry.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['action'] = action;
    if (parentCount != null) data['parent_count'] = parentCount;
    data['entries'] = entries.map((v) => v.toJson()).toList();
    return data;
  }
}

class JsonToplistEntry {
  late String name;
  late int count;
  bool? isRoot;
  String? deviceName;

  JsonToplistEntry({
    required this.name,
    required this.count,
    this.isRoot,
    this.deviceName,
  });

  JsonToplistEntry.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    count = json['count'];
    isRoot = json.containsKey('is_root') ? json['is_root'] : null;
    deviceName = json.containsKey('device_name') ? json['device_name'] : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['count'] = count;
    if (isRoot != null) data['is_root'] = isRoot;
    if (deviceName != null) data['device_name'] = deviceName;
    return data;
  }
}

class JsonWindow {
  late String label;
  late String start;
  late String end;
  String? date;

  JsonWindow({
    required this.label,
    required this.start,
    required this.end,
    this.date,
  });

  JsonWindow.fromJson(Map<String, dynamic> json) {
    label = json['label'];
    start = json['start'];
    end = json['end'];
    date = json.containsKey('date') ? json['date'] : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['label'] = label;
    data['start'] = start;
    data['end'] = end;
    if (date != null) data['date'] = date;
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

  JsonToplistV2Response toToplistV2Response(JsonString json) {
    return JsonToplistV2Response.fromJson(jsonDecode(json));
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

  Future<JsonToplistV2Response> getToplistV2({
    required String accountId,
    String? deviceTag,
    String? deviceName,
    int level = 1,
    String? action,
    String? domain,
    int limit = 10,
    String range = "24h",
    String? end,
    String? date,
    required Marker m,
  }) async {
    final params = {
      ApiParam.accountId: accountId,
      ApiParam.deviceTag: deviceTag ?? "",
      ApiParam.statsDeviceName: deviceName != null ? Uri.encodeComponent(deviceName) : "",
      ApiParam.toplistLevel: level.toString(),
      ApiParam.toplistAction: action ?? "",
      ApiParam.toplistDomain: domain ?? "",
      ApiParam.toplistLimit: limit.toString(),
      ApiParam.toplistRange: range,
      ApiParam.toplistEnd: end ?? "",
      ApiParam.toplistDate: date ?? "",
    };

    final result = await _api.get(ApiEndpoint.getToplistV2, m, params: params);
    return _marshal.toToplistV2Response(result);
  }

  // Keep old methods for backwards compatibility during migration
  Future<JsonToplistEndpoint> getToplist(bool blocked, Marker m) async {
    // MOCK: Temporarily return mock data instead of API call
    return _getMockToplist(blocked);
  }

  Future<JsonToplistEndpoint> getToplistForDevice(bool blocked, String deviceName, Marker m) async {
    // MOCK: Temporarily return mock data instead of API call
    return _getMockToplist(blocked);
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
