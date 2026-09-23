part of 'attach.dart';

/// Response of `POST v3/auth/link`.
///
/// [expires] is the absolute expiry and [expiresIn] its duration in seconds
/// (300 today). We keep both only to log how long a link should have lived
/// when a hand-off fails — the token itself is never stored.
class JsonAttachLink {
  late String token;
  late String expires;
  late int expiresIn;

  JsonAttachLink({
    required this.token,
    required this.expires,
    required this.expiresIn,
  });

  JsonAttachLink.fromJson(Map<String, dynamic> json) {
    try {
      token = json['token'];
      expires = json['expires'];
      expiresIn = json['expires_in'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['token'] = token;
    data['expires'] = expires;
    data['expires_in'] = expiresIn;
    return data;
  }
}

class JsonAttachMarshal {
  JsonAttachLink toLink(JsonString json) =>
      JsonAttachLink.fromJson(jsonDecode(json));

  /// The account ID is left as the endpoint placeholder for Http to fill in.
  JsonString payload() =>
      jsonEncode({"account_id": ApiParam.accountId.placeholder});
}
