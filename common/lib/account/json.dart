import 'dart:convert';

import '../http/http.dart';
import '../json/json.dart';
import '../util/di.dart';
import '../util/trace.dart';

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
  late final _http = di<HttpService>();

  Future<JsonAccount> getAccount(Trace trace, String accountId) async {
    final result =
        await _http.get(trace, "$jsonUrl/v2/account?account_id=$accountId");
    return JsonAccount.fromJson(jsonDecode(result)["account"]);
  }

  Future<JsonAccount> postAccount(Trace trace) async {
    final result =
        await _http.request(trace, "$jsonUrl/v2/account", HttpType.post);
    return JsonAccount.fromJson(jsonDecode(result)["account"]);
  }
}
