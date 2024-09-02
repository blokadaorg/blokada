part of '../../model.dart';

enum JsonCustomListAction { allow, block }

extension JsonCustomListActionToString on String {
  JsonCustomListAction toAction() {
    return JsonCustomListAction.values.firstWhere(
      (e) => e.name == this,
      orElse: () => JsonCustomListAction.allow,
    );
  }
}

class JsonCustomList {
  late String domainName;
  late JsonCustomListAction action;
  late bool wildcard;

  JsonCustomList({
    required this.domainName,
    required this.action,
    required this.wildcard,
  });

  JsonCustomList.fromJson(Map<String, dynamic> json) {
    try {
      domainName = json['domain_name'];
      action = json['action'].toString().toAction();
      wildcard = json['wildcard'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['domain_name'] = domainName;
    map['action'] = action.name;
    map['wildcard'] = wildcard;
    return map;
  }
}

class JsonCustomListEndpoint {
  late List<JsonCustomList> customlist;

  JsonCustomListEndpoint({required this.customlist});

  JsonCustomListEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      customlist = json['customlist']
          .map<JsonCustomList>((e) => JsonCustomList.fromJson(e))
          .toList();
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonCustomListPayload {
  late String? profileId;
  late String? domainName;
  late JsonCustomListAction? action;

  JsonCustomListPayload.forCreate({
    required this.profileId,
    required this.domainName,
    required this.action,
  }) : assert(profileId != null && domainName != null && action != null);

  JsonCustomListPayload.forDelete({
    required this.profileId,
    required this.domainName,
  })  : action = null,
        assert(profileId != null && domainName != null);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['account_id'] = ApiParam.accountId.placeholder;
    if (profileId != null) map['profile_id'] = profileId;
    if (domainName != null) map['domain_name'] = domainName;
    if (action != null) map['action'] = action!.name;
    return map;
  }
}

class JsonCustomListMarshal {
  List<JsonCustomList> toCustomList(JsonString json) {
    return JsonCustomListEndpoint.fromJson(jsonDecode(json)).customlist;
  }

  JsonCustomList toEntry(JsonString json) {
    return JsonCustomList.fromJson(jsonDecode(json)['customlist']);
  }

  JsonString fromPayload(JsonCustomListPayload payload) {
    return jsonEncode(payload.toJson());
  }
}
