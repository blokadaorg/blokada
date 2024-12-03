import 'dart:convert';

import 'package:common/core/core.dart';

import '../account/account.dart';
import '../http/http.dart';

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
  late String timestamp;

  JsonJournalEntry(
      {required this.deviceName,
      required this.domainName,
      required this.action,
      required this.list,
      required this.timestamp});

  JsonJournalEntry.fromJson(Map<String, dynamic> json) {
    try {
      deviceName = json['device_name'];
      domainName = json['domain_name'];
      action = json['action'];
      list = json['list'];
      timestamp = json['timestamp'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JournalJson {
  late final _http = Core.get<HttpService>();
  late final _account = Core.get<AccountStore>();

  Future<List<JsonJournalEntry>> getEntries(Marker m) async {
    final result =
        await _http.get("$jsonUrl/v2/activity?account_id=${_account.id}", m);
    return JsonJournalEndpoint.fromJson(jsonDecode(result)).activity;
  }
}
