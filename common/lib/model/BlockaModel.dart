class StatsEndpoint {
  String? totalAllowed;
  String? totalBlocked;
  Stats? stats;

  StatsEndpoint({this.totalAllowed, this.totalBlocked, this.stats});

  StatsEndpoint.fromJson(Map<String, dynamic> json) {
    totalAllowed = json['total_allowed'];
    totalBlocked = json['total_blocked'];
    stats = json['stats'] != null ? Stats.fromJson(json['stats']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_allowed'] = totalAllowed;
    data['total_blocked'] = totalBlocked;
    if (stats != null) {
      data['stats'] = stats!.toJson();
    }
    return data;
  }
}

class Stats {
  List<Metrics>? metrics;

  Stats({this.metrics});

  Stats.fromJson(Map<String, dynamic> json) {
    if (json['metrics'] != null) {
      metrics = <Metrics>[];
      json['metrics'].forEach((v) {
        metrics!.add(Metrics.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (metrics != null) {
      data['metrics'] = metrics!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Metrics {
  Tags? tags;
  List<Dps>? dps;

  Metrics({this.tags, this.dps});

  Metrics.fromJson(Map<String, dynamic> json) {
    tags = json['tags'] != null ? Tags.fromJson(json['tags']) : null;
    if (json['dps'] != null) {
      dps = <Dps>[];
      json['dps'].forEach((v) {
        dps!.add(Dps.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (tags != null) {
      data['tags'] = tags!.toJson();
    }
    if (dps != null) {
      data['dps'] = dps!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Tags {
  String? action;
  String? deviceName;

  Tags({this.action, this.deviceName});

  Tags.fromJson(Map<String, dynamic> json) {
    action = json['action'];
    deviceName = json['device_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['action'] = action;
    data['device_name'] = deviceName;
    return data;
  }
}

class Dps {
  String? timestamp;
  double? value;

  Dps({this.timestamp, this.value});

  Dps.fromJson(Map<String, dynamic> json) {
    timestamp = json['timestamp'];
    value = double.parse(json['value'].toString());
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['timestamp'] = timestamp;
    data['value'] = value;
    return data;
  }
}
