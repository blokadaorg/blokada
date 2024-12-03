import 'dart:convert';

import 'package:common/core/core.dart';

import '../http/http.dart';

class JsonAccount {
  late String id;
  String? activeUntil;
  bool? active;
  String? type;
  String? paymentSource;

  JsonAccount({
    required this.id,
    required this.activeUntil,
    required this.active,
    required this.type,
  });

  isActive() {
    return active ?? false;
  }

  JsonAccount.fromJson(Map<String, dynamic> json) {
    try {
      id = json['id'];
      activeUntil = json['active_until'];
      active = json['active'];
      type = json['type'];
      paymentSource = json['payment_source'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['active_until'] = activeUntil;
    data['active'] = active;
    data['type'] = type;
    data['payment_source'] = paymentSource;
    return data;
  }
}

class AccountJson {
  late final _http = Core.get<HttpService>();

  Future<JsonAccount> getAccount(String accountId, Marker m) async {
    final result =
        await _http.get("$jsonUrl/v2/account?account_id=$accountId", m);
    return JsonAccount.fromJson(jsonDecode(result)["account"]);
  }

  Future<JsonAccount> postAccount(Marker m) async {
    final result = await _http.request("$jsonUrl/v2/account", HttpType.post, m);
    return JsonAccount.fromJson(jsonDecode(result)["account"]);
  }
}
