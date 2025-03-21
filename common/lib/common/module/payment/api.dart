part of 'payment.dart';

class JsonAdaptyPayload {
  late String accountId;
  late String profile;
  late String platform;

  JsonAdaptyPayload({
    required this.profile,
    required this.platform,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['account_id'] = api.ApiParam.accountId.placeholder;
    data['profile'] = profile;
    data['platform'] = platform;
    return data;
  }
}

class JsonAdaptyMarshal {
  JsonAccount toAccount(JsonString json) {
    return JsonAccount.fromJson(jsonDecode(json)["account"]);
  }

  JsonString fromPayload(JsonAdaptyPayload payload) {
    return jsonEncode(payload.toJson());
  }
}

class PaymentApi {
  late final _api = Core.get<api.Api>();
  late final _marshal = JsonAdaptyMarshal();

  Future<JsonAccount> postCheckout(Marker m, String profile) async {
    // TODO: ipados
    final platform = Core.act.platform == PlatformType.iOS ? "iOS" : "Android";

    final payload = JsonAdaptyPayload(profile: profile, platform: platform);

    final response = await _api.request(api.ApiEndpoint.postAdaptyCheckout, m,
        payload: _marshal.fromPayload(payload));
    return _marshal.toAccount(response);
  }
}
