import 'dart:convert';

import '../account/account.dart';
import '../http/http.dart';
import '../json/json.dart';
import '../plus/keypair/keypair.dart';
import '../util/di.dart';
import '../util/trace.dart';

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

  Future<void> postToken(Trace trace, String appleToken) async {
    final payload = JsonAppleNotificationPayload(
      accountId: _account.id,
      publicKey: _keypair.currentKeypair!.publicKey,
      appleToken: appleToken,
    );

    await _http.request(trace, "$jsonUrl/v2/apple/device", HttpType.post,
        payload: jsonEncode(payload.toJson()));
  }
}
