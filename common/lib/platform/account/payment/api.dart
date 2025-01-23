import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';

import '../api.dart';

class JsonPaymentCheckoutPayload {
  String? receipt;
  String? purchaseToken;
  String? subscriptionId;

  JsonPaymentCheckoutPayload.forApple({
    required this.receipt,
  });

  JsonPaymentCheckoutPayload.forGoogle({
    required this.purchaseToken,
    required this.subscriptionId,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['account_id'] = ApiParam.accountId.placeholder;
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

class AccountPaymentMarshal {
  JsonAccount toAccount(JsonString json) {
    return JsonAccount.fromJson(jsonDecode(json)["account"]);
  }

  JsonString fromPayload(Map<String, dynamic> payload) {
    return jsonEncode(payload);
  }
}

class AccountPaymentApi {
  late final _api = Core.get<Api>();
  late final _marshal = AccountPaymentMarshal();

  Future<JsonAccount> postCheckout(
      String blob, PlatformType p, Marker m) async {
    dynamic payload = <String, dynamic>{};
    ApiEndpoint endpoint;

    if (p == PlatformType.iOS) {
      payload = JsonPaymentCheckoutPayload.forApple(
        receipt: blob,
      ).toJson();

      endpoint = ApiEndpoint.postCheckoutAppleV2;
    } else if (p == PlatformType.android) {
      final transactionDetails = blob.split(":::");
      if (transactionDetails.length != 2) {
        throw ArgumentError("Invalid transaction details for Google payment");
      }

      payload = JsonPaymentCheckoutPayload.forGoogle(
        purchaseToken: transactionDetails[0],
        subscriptionId: transactionDetails[1],
      ).toJson();

      endpoint = ApiEndpoint.postCheckoutGplayV2;
    } else {
      throw UnsupportedError("Unsupported platform");
    }

    final response =
        await _api.request(endpoint, m, payload: _marshal.fromPayload(payload));
    return _marshal.toAccount(response);
  }
}
