part of '../../model.dart';

RegExp _templateInAlias = RegExp(r' \((\w+)\)');

String generateProfileAlias(String displayAlias, String template) {
  return "$displayAlias ($template)";
}

class JsonProfile {
  late String profileId;
  late String alias;
  late List<String> lists;
  late bool safeSearch;

  String get template => _templateInAlias.firstMatch(alias)?.group(1) ?? "";
  String get displayAlias => alias.removeSuffix(" ($template)");

  JsonProfile({
    required this.profileId,
    required this.alias,
    required this.lists,
    required this.safeSearch,
  });

  JsonProfile.fromJson(Map<String, dynamic> json) {
    try {
      profileId = json['profile_id'];
      alias = json['alias'];
      lists = json['lists'] != null ? List<String>.from(json['lists']) : [];
      safeSearch = json['safe_search'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  JsonProfile copy({
    String? alias,
    List<String>? lists,
    bool? safeSearch,
  }) {
    return JsonProfile(
      profileId: profileId,
      alias: alias ?? this.alias,
      lists: lists ?? this.lists,
      safeSearch: safeSearch ?? this.safeSearch,
    );
  }
}

class JsonProfileEndpoint {
  late List<JsonProfile> profiles;

  JsonProfileEndpoint({required this.profiles});

  JsonProfileEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      profiles = json['profiles']
          .map<JsonProfile>((e) => JsonProfile.fromJson(e))
          .toList();
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonProfilePayload {
  late String? profileId;
  late String? alias;
  late List<String>? lists;
  late bool? safeSearch;

  JsonProfilePayload.forCreate({
    required this.alias,
    required this.lists,
    required this.safeSearch,
  }) : profileId = null;

  JsonProfilePayload.forUpdateAlias({
    required this.profileId,
    this.alias,
  })  : lists = null,
        safeSearch = null,
        assert(profileId != null && alias != null);

  JsonProfilePayload.forUpdateConfig({
    required this.profileId,
    this.lists,
    this.safeSearch,
  })  : alias = null,
        assert(profileId != null && lists != null && safeSearch != null);

  JsonProfilePayload.forDelete({
    required this.profileId,
  })  : alias = null,
        lists = null,
        safeSearch = null,
        assert(profileId != null);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'account_id': ApiParam.accountId.placeholder,
    };
    if (profileId != null) json['profile_id'] = profileId!;
    if (alias != null) json['alias'] = alias!;
    if (lists != null) json['lists'] = lists!;
    if (safeSearch != null) json['safe_search'] = safeSearch!;
    print("JsonProfilePayload.toJson: $json");
    return json;
  }
}

class JsonProfileMarshal {
  List<JsonProfile> toProfiles(JsonString json) {
    return JsonProfileEndpoint.fromJson(jsonDecode(json)).profiles;
  }

  JsonProfile toProfile(JsonString json) {
    return JsonProfile.fromJson(jsonDecode(json)['profile']);
  }

  JsonString fromPayload(JsonProfilePayload payload) {
    return jsonEncode(payload.toJson());
  }
}
