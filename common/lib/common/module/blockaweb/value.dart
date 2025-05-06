part of 'blockaweb.dart';

// A simple struct provided to blockaweb extension that gives it app status.
class JsonBlockaweb {
  late DateTime timestamp;
  late bool active;

  JsonBlockaweb({
    required this.timestamp,
    required this.active,
  });

  JsonBlockaweb.fromJson(Map<String, dynamic> json) {
    timestamp = DateTime.tryParse(json['timestamp'] ?? "") ?? DateTime(0);
    active = json['active'] as bool;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['timestamp'] = timestamp.toIso8601String();
    data['active'] = active;
    return data;
  }

  @override
  String toString() {
    return "JsonBlockaweb{timestamp: $timestamp, active: $active}";
  }
}

class BlockawebAppStatusValue extends JsonPersistedValue<JsonBlockaweb> {
  BlockawebAppStatusValue() : super("blockaweb:status");

  @override
  JsonBlockaweb fromJson(Map<String, dynamic> json) =>
      JsonBlockaweb.fromJson(json);

  @override
  Map<String, dynamic> toJson(JsonBlockaweb value) => value.toJson();
}

class BlockawebPingValue extends JsonPersistedValue<JsonBlockaweb> {
  BlockawebPingValue() : super("blockaweb:ping");

  @override
  JsonBlockaweb fromJson(Map<String, dynamic> json) =>
      JsonBlockaweb.fromJson(json);

  @override
  Map<String, dynamic> toJson(JsonBlockaweb value) => value.toJson();
}
