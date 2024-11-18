import 'dart:convert';

import 'package:common/core/core.dart';

import '../account/account.dart';
import '../http/http.dart';

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
  late final _http = DI.get<HttpService>();
  late final _account = DI.get<AccountStore>();

  Future<List<JsonCustomEntry>> getEntries(Marker m) async {
    final result =
        await _http.get("$jsonUrl/v2/customlist?account_id=${_account.id}", m);
    return JsonCustomEndpoint.fromJson(jsonDecode(result)).customList;
  }

  Future<void> postEntry(JsonCustomEntry entry, Marker m) async {
    final payload = JsonCustomPayload.forEntry(entry, accountId: _account.id);
    await _http.request("$jsonUrl/v2/customlist", HttpType.post, m,
        payload: jsonEncode(payload.toJson()));
  }

  Future<void> deleteEntry(JsonCustomEntry entry, Marker m) async {
    final payload = JsonCustomPayload.forEntry(entry, accountId: _account.id);
    await _http.request("$jsonUrl/v2/customlist", HttpType.delete, m,
        payload: jsonEncode(payload.toJson()));
  }
}
