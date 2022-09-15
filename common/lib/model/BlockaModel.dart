class StatsEndpoint {

  late String totalAllowed;
  late String totalBlocked;
  late Stats stats;

  StatsEndpoint({
    required this.totalAllowed, required this.totalBlocked, required this.stats
  });

  StatsEndpoint.fromJson(Map<String, dynamic> json) {
    totalAllowed = json['total_allowed'];
    totalBlocked = json['total_blocked'];
    stats = Stats.fromJson(json['stats']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_allowed'] = totalAllowed;
    data['total_blocked'] = totalBlocked;
    data['stats'] = stats.toJson();
    return data;
  }

}

class Stats {

  late List<Metrics> metrics;

  Stats({required this.metrics});

  Stats.fromJson(Map<String, dynamic> json) {
    metrics = <Metrics>[];
    json['metrics'].forEach((v) {
      metrics.add(Metrics.fromJson(v));
    });
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['metrics'] = metrics.map((v) => v.toJson()).toList();
    return data;
  }

}

class Metrics {

  late Tags tags;
  late List<Dps> dps;

  Metrics({required this.tags, required this.dps});

  Metrics.fromJson(Map<String, dynamic> json) {
    tags = Tags.fromJson(json['tags']);
    dps = <Dps>[];
    json['dps'].forEach((v) {
      dps.add(Dps.fromJson(v));
    });
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['tags'] = tags.toJson();
    data['dps'] = dps.map((v) => v.toJson()).toList();
    return data;
  }

}

class Tags {

  late String action;
  String? deviceName;

  Tags({required this.action, this.deviceName});

  Tags.fromJson(Map<String, dynamic> json) {
    action = json['action'];
    deviceName = json.containsKey('device_name') ? json['device_name'] : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['action'] = action;
    data['device_name'] = deviceName;
    return data;
  }

}

class Dps {

  late int timestamp;
  late double value;

  Dps({required this.timestamp, required this.value});

  Dps.fromJson(Map<String, dynamic> json) {
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
