import 'dart:convert';

import 'package:common/core/core.dart';

import '../../http/http.dart';
import '../account.dart';
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
  late final _http = dep<HttpService>();
  late final _account = dep<AccountStore>();

  Future<JsonAccount> postCheckout(
      String blob, PlatformType p, Marker m) async {
    dynamic payload = <String, dynamic>{};
    String endpoint;

    if (p == PlatformType.iOS) {
      payload = JsonPaymentCheckoutPayload.forApple(
        accountId: _account.id,
        receipt: blob,
      ).toJson();
      endpoint = "apple";
    } else if (p == PlatformType.android) {
      final transactionDetails = blob.split(":::");
      if (transactionDetails.length != 2) {
        throw ArgumentError("Invalid transaction details for Google payment");
      }

      payload = JsonPaymentCheckoutPayload.forGoogle(
        accountId: _account.id,
        purchaseToken: transactionDetails[0],
        subscriptionId: transactionDetails[1],
      ).toJson();
      endpoint = "gplay";
    } else {
      throw UnsupportedError("Unsupported platform");
    }

    final result = await _http.request(
        "$jsonUrl/v2/$endpoint/checkout", HttpType.post, m,
        payload: jsonEncode(payload));
    return JsonAccount.fromJson(jsonDecode(result)["account"]);
  }
}
