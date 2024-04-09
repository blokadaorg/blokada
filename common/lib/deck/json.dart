import 'dart:convert';

import '../../../../account/account.dart';
import '../../../../http/http.dart';
import '../../../../json/json.dart';
import '../../../../util/di.dart';
import '../../../../util/trace.dart';

class JsonListEndpoint {
  late List<JsonListItem> lists;

  JsonListEndpoint({required this.lists});

  JsonListEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      lists = <JsonListItem>[];
      json['lists'].forEach((v) {
        lists.add(JsonListItem.fromJson(v));
      });
    } on TypeError catch (e) {
      throw JsonError(json, e);
    } on NoSuchMethodError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonListItem {
  late String id;
  late String path;
  late String vendor; // List vendor like oisd, goodbyeads
  late String variant; // List variant like small, big
  late bool managed;
  late bool allowlist;

  JsonListItem({
    required this.id,
    required this.path,
    required this.vendor,
    required this.variant,
    required this.managed,
    required this.allowlist,
  });

  JsonListItem.fromJson(Map<String, dynamic> json) {
    try {
      id = json['id'];
      path = json['name'];
      vendor = path.split("/")[2];
      variant = path.split("/")[3];
      managed = json['managed'];
      allowlist = json['is_allowlist'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  @override
  String toString() =>
      "JsonListItem{id: $id, vendor: $vendor, variant: $variant, managed: $managed, allowlist: $allowlist}";
}

class DeckJson {
  late final _http = dep<HttpService>();
  late final _account = dep<AccountStore>();

  Future<List<JsonListItem>> getLists(Trace trace) async {
    final result =
        await _http.get(trace, "$jsonUrl/v2/list?account_id=${_account.id}");
    return JsonListEndpoint.fromJson(jsonDecode(result)).lists;
  }
}
