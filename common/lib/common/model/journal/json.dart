part of '../../model.dart';

class JsonJournalEndpoint {
  late List<JsonJournalEntry> activity;

  JsonJournalEndpoint({required this.activity});

  JsonJournalEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      activity = <JsonJournalEntry>[];
      json['activity'].forEach((v) {
        activity.add(JsonJournalEntry.fromJson(v));
      });
    } on TypeError catch (e) {
      throw JsonError(json, e);
    } on NoSuchMethodError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonJournalEntry {
  late String deviceName;
  late String domainName;
  late String action;
  late String list;
  late String profile;
  late String timestamp;

  JsonJournalEntry({
    required this.deviceName,
    required this.domainName,
    required this.action,
    required this.list,
    required this.profile,
    required this.timestamp,
  });

  JsonJournalEntry.fromJson(Map<String, dynamic> json) {
    try {
      deviceName = json['device_name'];
      domainName = json['domain_name'];
      action = json['action'];
      list = json['list'];
      profile = json['profile'];
      timestamp = json['timestamp'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonJournalMarshal {
  JsonJournalEndpoint toEndpoint(JsonString json) {
    return JsonJournalEndpoint.fromJson(jsonDecode(json));
  }
}
