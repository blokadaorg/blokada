import 'dart:convert';

import '../account/account.dart';
import '../env/env.dart';
import '../http/http.dart';
import '../json/json.dart';
import '../util/di.dart';
import '../util/trace.dart';

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
  late final _http = dep<HttpService>();
  late final _account = dep<AccountStore>();

  Future<List<JsonJournalEntry>> getEntries(Trace trace) async {
    final result = await _http.get(
        trace, "$jsonUrl/v2/activity?account_id=${_account.id}");
    return JsonJournalEndpoint.fromJson(jsonDecode(result)).activity;
  }
}
