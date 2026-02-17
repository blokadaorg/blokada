part of 'notification.dart';

class JsonAppleNotificationPayload {
  late String publicKey;
  late String appleToken;

  JsonAppleNotificationPayload({
    required this.publicKey,
    required this.appleToken,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['account_id'] = ApiParam.accountId.placeholder;
    data['public_key'] = publicKey;
    data['device_token'] = appleToken;
    return data;
  }
}

class JsonFcmNotificationPayload {
  late String deviceTag;
  late String token;
  late String platform;
  late List<String> locales;

  JsonFcmNotificationPayload({
    required this.deviceTag,
    required this.token,
    required this.platform,
    required this.locales,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['account_id'] = ApiParam.accountId.placeholder;
    data['device_tag'] = deviceTag;
    data['token'] = token;
    data['platform'] = platform;
    data['locales'] = locales;
    return data;
  }
}

class JsonNotificationConfig {
  final bool optOut;

  JsonNotificationConfig({required this.optOut});

  JsonNotificationConfig.fromJson(Map<String, dynamic> json)
      : optOut = json['opt_out'] == true;
}

class JsonNotificationConfigPayload {
  final bool optOut;

  JsonNotificationConfigPayload({required this.optOut});

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['account_id'] = ApiParam.accountId.placeholder;
    data['opt_out'] = optOut;
    return data;
  }
}

class NotificationMarshal {
  JsonString fromPayload(JsonAppleNotificationPayload payload) {
    return jsonEncode(payload.toJson());
  }

  JsonString fromFcmPayload(JsonFcmNotificationPayload payload) {
    return jsonEncode(payload.toJson());
  }

  JsonNotificationConfig toConfig(JsonString json) {
    return JsonNotificationConfig.fromJson(jsonDecode(json));
  }

  JsonString fromConfig(JsonNotificationConfigPayload payload) {
    return jsonEncode(payload.toJson());
  }
}

class NotificationApi {
  late final _api = Core.get<Api>();
  late final _marshal = NotificationMarshal();

  Future<void> postToken(
      String keypairPublicKey, String appleToken, Marker m) async {
    final payload = JsonAppleNotificationPayload(
      publicKey: keypairPublicKey,
      appleToken: appleToken,
    );

    await _api.request(ApiEndpoint.postNotificationToken, m,
        payload: _marshal.fromPayload(payload));
  }

  Future<void> postFcmToken(
      String deviceTag,
      String token,
      String platform,
      List<String> locales,
      Marker m,
      ) async {
    final payload = JsonFcmNotificationPayload(
      deviceTag: deviceTag,
      token: token,
      platform: platform,
      locales: locales,
    );

    await _api.request(ApiEndpoint.postFcmNotificationToken, m,
        payload: _marshal.fromFcmPayload(payload));
  }

  Future<JsonNotificationConfig> getConfig(Marker m) async {
    final result = await _api.request(ApiEndpoint.getNotificationConfigV2, m);
    return _marshal.toConfig(result);
  }

  Future<void> putConfig(bool optOut, Marker m) async {
    final payload = JsonNotificationConfigPayload(optOut: optOut);
    await _api.request(
      ApiEndpoint.putNotificationConfigV2,
      m,
      payload: _marshal.fromConfig(payload),
    );
  }
}
