part of '../../model.dart';

class JsonAuthEndpoint {
  late String? token;
  late String deviceTag;
  late String expires;
  late List<String> scopes;

  JsonAuthEndpoint({
    required this.token,
    required this.deviceTag,
    required this.expires,
    required this.scopes,
  });

  JsonAuthEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      token = json['token'];
      deviceTag = json['device_tag'];
      expires = json['expires'];
      scopes = json['scopes'].cast<String>();
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['token'] = token;
    data['device_tag'] = deviceTag;
    data['expires'] = expires;
    data['scopes'] = scopes;
    return data;
  }
}

extension JsonAuthEndpointExt on JsonAuthEndpoint {
  DateTime get expiry => DateTime.tryParse(expires) ?? DateTime.now();

  bool get isExpired {
    final expiry = DateTime.tryParse(expires);
    return expiry == null || expiry.isBefore(DateTime.now());
  }
}

class JsonAuthPayload {
  late String accountId;
  late String deviceTag;

  JsonAuthPayload({
    required this.accountId,
    required this.deviceTag,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['account_id'] = accountId;
    data['device_tag'] = deviceTag;
    return data;
  }
}

class JsonAuthMarshal {
  JsonAuthEndpoint toEndpoint(JsonString json) {
    return JsonAuthEndpoint.fromJson(jsonDecode(json));
  }

  JsonString fromPayload(JsonAuthPayload p) {
    return jsonEncode(p.toJson());
  }
}
