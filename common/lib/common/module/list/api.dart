part of 'list.dart';

class JsonListEndpoint with Logging {
  late List<JsonListItem> lists;

  JsonListEndpoint({required this.lists});

  JsonListEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      lists = <JsonListItem>[];
      json['lists'].forEach((v) {
        try {
          lists.add(JsonListItem.fromJson(v));
        } catch (e, s) {
          log(Markers.root).e(
              msg: "Failed to parse blocklist list item, ignoring: $v",
              err: e,
              stack: s);
        }
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

class ListMarshal {
  List<JsonListItem> lists(JsonString json) {
    return JsonListEndpoint.fromJson(jsonDecode(json)).lists;
  }
}

class ListApi {
  late final _api = Core.get<Api>();

  Future<List<JsonListItem>> get(Marker m) async {
    final response = await _api.get(ApiEndpoint.getLists, m);
    return ListMarshal().lists(response);
  }
}
