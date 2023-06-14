import 'dart:convert';

import '../account/account.dart';
import '../env/env.dart';
import '../http/http.dart';
import '../json/json.dart';
import '../util/di.dart';
import '../util/trace.dart';

class JsonCustomEndpoint {
  late List<JsonCustomEntry> customList;

  JsonCustomEndpoint({required this.customList});

  JsonCustomEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      customList = <JsonCustomEntry>[];
      json['customlist'].forEach((v) {
        customList.add(JsonCustomEntry.fromJson(v));
      });
    } on TypeError catch (e) {
      throw JsonError(json, e);
    } on NoSuchMethodError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonCustomEntry {
  late String domainName;
  late String action;

  JsonCustomEntry({required this.domainName, required this.action});

  JsonCustomEntry.fromJson(Map<String, dynamic> json) {
    try {
      domainName = json['domain_name'];
      action = json['action'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonCustomPayload {
  late String accountId;
  late String domainName;
  late String action;

  JsonCustomPayload.forEntry(
    JsonCustomEntry entry, {
    required this.accountId,
  })  : domainName = entry.domainName,
        action = entry.action;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['account_id'] = accountId;
    data['domain_name'] = domainName;
    data['action'] = action;
    return data;
  }
}

class CustomJson {
  late final _http = dep<HttpService>();
  late final _account = dep<AccountStore>();

  Future<List<JsonCustomEntry>> getEntries(Trace trace) async {
    final result = await _http.get(
        trace, "$jsonUrl/v2/customlist?account_id=${_account.id}");
    return JsonCustomEndpoint.fromJson(jsonDecode(result)).customList;
  }

  Future<void> postEntry(Trace trace, JsonCustomEntry entry) async {
    final payload = JsonCustomPayload.forEntry(entry, accountId: _account.id);
    await _http.request(trace, "$jsonUrl/v2/customlist", HttpType.post,
        payload: jsonEncode(payload.toJson()));
  }

  Future<void> deleteEntry(Trace trace, JsonCustomEntry entry) async {
    final payload = JsonCustomPayload.forEntry(entry, accountId: _account.id);
    await _http.request(trace, "$jsonUrl/v2/customlist", HttpType.delete,
        payload: jsonEncode(payload.toJson()));
  }
}
