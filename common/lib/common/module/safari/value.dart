part of 'safari.dart';

// A simple struct provided to blockaweb extension that gives it app status.
// Also used to pass status the other way (blockaweb status to the app).
class JsonBlockaweb {
  late DateTime timestamp;
  late bool active;
  late bool freemium;
  late DateTime? freemiumYoutubeUntil;

  JsonBlockaweb({
    required this.timestamp,
    required this.active,
    this.freemium = false,
    this.freemiumYoutubeUntil,
  });

  JsonBlockaweb.fromJson(Map<String, dynamic> json) {
    timestamp = DateTime.tryParse(json['timestamp'] ?? "") ?? DateTime(0);
    active = json['active'] as bool;
    freemium = json['freemium'] as bool? ?? false;
    freemiumYoutubeUntil = json['freemium_youtube_until'] != null
        ? DateTime.tryParse(json['freemium_youtube_until'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['timestamp'] = timestamp.toIso8601String();
    data['active'] = active;
    data['freemium'] = freemium;
    if (freemiumYoutubeUntil != null) {
      data['freemium_youtube_until'] = freemiumYoutubeUntil!.toIso8601String();
    }
    return data;
  }

  @override
  String toString() {
    return "JsonBlockaweb{timestamp: $timestamp, active: $active, freemium: $freemium, freemiumYoutubeUntil: $freemiumYoutubeUntil}";
  }
}

// Status of this app, passed to the blockaweb extension.
class BlockawebAppStatusValue extends JsonPersistedValue<JsonBlockaweb> {
  BlockawebAppStatusValue() : super("blockaweb:status");

  @override
  JsonBlockaweb fromJson(Map<String, dynamic> json) => JsonBlockaweb.fromJson(json);

  @override
  Map<String, dynamic> toJson(JsonBlockaweb value) => value.toJson();
}

// Status of blockaweb, passed to this app.
class BlockawebPingValue extends JsonPersistedValue<JsonBlockaweb> {
  BlockawebPingValue() : super("blockaweb:ping");

  @override
  JsonBlockaweb fromJson(Map<String, dynamic> json) => JsonBlockaweb.fromJson(json);

  @override
  Map<String, dynamic> toJson(JsonBlockaweb value) => value.toJson();
}
