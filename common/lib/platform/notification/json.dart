import 'dart:convert';

import 'package:common/core/core.dart';

import '../account/account.dart';
import '../http/http.dart';
import '../plus/keypair/keypair.dart';

class JsonAppleNotificationPayload {
  late String accountId;
  late String publicKey;
  late String appleToken;

  JsonAppleNotificationPayload({
    required this.accountId,
    required this.publicKey,
    required this.appleToken,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['account_id'] = accountId;
    data['public_key'] = publicKey;
    data['device_token'] = appleToken;
    return data;
  }
}

class NotificationJson {
  late final _http = dep<HttpService>();
  late final _account = dep<AccountStore>();
  late final _keypair = dep<PlusKeypairStore>();

  Future<void> postToken(String appleToken, Marker m) async {
    final payload = JsonAppleNotificationPayload(
      accountId: _account.id,
      publicKey: _keypair.currentKeypair!.publicKey,
      appleToken: appleToken,
    );

    await _http.request("$jsonUrl/v2/apple/device", HttpType.post, m,
        payload: jsonEncode(payload.toJson()));
  }
}
