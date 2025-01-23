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

class NotificationMarshal {
  JsonString fromPayload(JsonAppleNotificationPayload payload) {
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
}
