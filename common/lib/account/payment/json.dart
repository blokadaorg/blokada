import 'dart:convert';
import 'dart:io';

import '../../env/env.dart';
import '../../http/http.dart';
import '../../json/json.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../json.dart';

class JsonPaymentCheckoutPayload {
  String accountId;
  String? receipt;
  String? purchaseToken;
  String? subscriptionId;

  JsonPaymentCheckoutPayload.forApple({
    required this.accountId,
    required this.receipt,
  });

  JsonPaymentCheckoutPayload.forGoogle({
    required this.accountId,
    required this.purchaseToken,
    required this.subscriptionId,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['account_id'] = accountId;
    if (receipt != null) {
      data['receipt'] = receipt;
    }
    if (purchaseToken != null) {
      data['purchase_token'] = purchaseToken;
    }
    if (subscriptionId != null) {
      data['subscription_id'] = subscriptionId;
    }
    return data;
  }
}

class AccountPaymentJson {
  late final _http = di<HttpService>();
  late final _env = di<EnvStore>();

  Future<JsonAccount> postCheckout(Trace trace, String blob) async {
    dynamic payload = <String, dynamic>{};
    String endpoint;

    if (Platform.isIOS) {
      payload = JsonPaymentCheckoutPayload.forApple(
        accountId: _env.currentUser,
        receipt: blob,
      ).toJson();
      endpoint = "apple";
    } else if (Platform.isAndroid) {
      final transactionDetails = blob.split(":::");
      if (transactionDetails.length != 2) {
        throw ArgumentError("Invalid transaction details for Google payment");
      }

      payload = JsonPaymentCheckoutPayload.forGoogle(
        accountId: _env.currentUser,
        purchaseToken: transactionDetails[0],
        subscriptionId: transactionDetails[1],
      ).toJson();
      endpoint = "gplay";
    } else {
      throw UnsupportedError("Unsupported platform");
    }

    final result = await _http.request(
        trace, "$jsonUrl/v2/$endpoint/checkout", HttpType.post,
        payload: jsonEncode(payload));
    return JsonAccount.fromJson(jsonDecode(result)["account"]);
  }
}
