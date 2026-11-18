import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';

enum EssentialsOnboardingOrder {
  afterPaywall("after_paywall"),
  beforePaywall("before_paywall");

  final String apiValue;

  const EssentialsOnboardingOrder(this.apiValue);

  static EssentialsOnboardingOrder fromApiValue(String? value) {
    return EssentialsOnboardingOrder.values.firstWhere(
      (order) => order.apiValue == value,
      orElse: () => EssentialsOnboardingOrder.afterPaywall,
    );
  }
}

class JsonAccount {
  static const String _attrFreemium = 'freemium';
  static const String _attrFreemiumYoutubeUntil = 'freemium_youtube_until';
  static const String _attrEssentialsOnboardingOrder = 'essentials_onboarding_order';

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
    return attributes![_attrFreemium] == true;
  }

  DateTime? getFreemiumYoutubeUntil() {
    if (attributes == null) return null;
    final freemiumUntil = attributes![_attrFreemiumYoutubeUntil];
    if (freemiumUntil is String) {
      return DateTime.tryParse(freemiumUntil);
    }
    return null;
  }

  /// Defaults to the current post-paywall onboarding order when the API does
  /// not provide a value so existing freemium behavior stays unchanged.
  EssentialsOnboardingOrder getEssentialsOnboardingOrder() {
    if (attributes == null) return EssentialsOnboardingOrder.afterPaywall;
    final value = attributes![_attrEssentialsOnboardingOrder];
    return EssentialsOnboardingOrder.fromApiValue(value is String ? value : null);
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
