import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';

class JsonAccount {
  late String id;
  String? activeUntil;
  bool? active;
  String? type;
  String? paymentSource;
  Map<String, dynamic>? attributes;

  JsonAccount({
    required this.id,
    required this.activeUntil,
    required this.active,
    required this.type,
    this.attributes,
  });

  isActive() {
    return active ?? false;
  }

  isFreemium() {
    if (attributes == null) return false;
    return attributes!['freemium'] == true;
  }

  DateTime? getFreemiumYoutubeUntil() {
    if (attributes == null) return null;
    final freemiumUntil = attributes!['freemium_youtube_until'];
    if (freemiumUntil is String) {
      return DateTime.tryParse(freemiumUntil);
    }
    return null;
  }

  DateTime getActiveUntil() {
    if (activeUntil == null || activeUntil!.isEmpty) {
      return DateTime(0);
    }
    final date = DateTime.tryParse(activeUntil!);
    return date ?? DateTime(0);
  }

  bool hasBeenActiveBefore() {
    return paymentSource?.isNotEmpty ?? false;
  }

  JsonAccount.fromJson(Map<String, dynamic> json) {
    try {
      id = json['id'];
      activeUntil = json['active_until'];
      active = json['active'];
      type = json['type'];
      paymentSource = json['payment_source'];
      attributes = json['attributes'] as Map<String, dynamic>?;
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
    if (attributes != null) {
      data['attributes'] = attributes;
    }
    return data;
  }
}

class AccountMarshal {
  JsonAccount toAccount(JsonString json) {
    return JsonAccount.fromJson(jsonDecode(json)["account"]);
  }
}

class AccountApi {
  late final _api = Core.get<Api>();
  late final _marshal = AccountMarshal();

  Future<JsonAccount> getAccount(String accountId, Marker m) async {
    final result = await _api.get(ApiEndpoint.getAccountV2, m, params: {
      ApiParam.accountId: accountId,
    });
    return _marshal.toAccount(result);
  }

  Future<JsonAccount> postAccount(Marker m) async {
    final result = await _api.request(ApiEndpoint.postAccountV2, m, skipResolvingParams: true);
    return _marshal.toAccount(result);
  }
}
