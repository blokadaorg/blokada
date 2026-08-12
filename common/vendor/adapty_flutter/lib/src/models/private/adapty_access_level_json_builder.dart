//
//  adapty_access_level_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_access_level.dart';

extension AdaptyAccessLevelJSONBuilder on AdaptyAccessLevel {
  static AdaptyAccessLevel fromJsonValue(Map<String, dynamic> json) {
    return AdaptyAccessLevel._(
      json.string(_Keys.id),
      json.boolean(_Keys.isActive),
      json.string(_Keys.vendorProductId),
      json.string(_Keys.store),
      json.dateTime(_Keys.activatedAt),
      json.dateTimeIfPresent(_Keys.renewedAt),
      json.dateTimeIfPresent(_Keys.expiresAt),
      json.boolean(_Keys.isLifetime),
      json.stringIfPresent(_Keys.activeIntroductoryOfferType),
      json.stringIfPresent(_Keys.activePromotionalOfferType),
      AdaptySDKNative.isIOS ? json.stringIfPresent(_Keys.iosActiveDiscountId) : null,
      AdaptySDKNative.isAndroid ? json.stringIfPresent(_Keys.androidActiveOfferId) : null,
      json.boolean(_Keys.willRenew),
      json.boolean(_Keys.isInGracePeriod),
      json.dateTimeIfPresent(_Keys.unsubscribedAt),
      json.dateTimeIfPresent(_Keys.billingIssueDetectedAt),
      json.dateTimeIfPresent(_Keys.startsAt),
      json.stringIfPresent(_Keys.cancellationReason),
      json.boolean(_Keys.isRefund),
    );
  }
}

class _Keys {
  static const id = 'id';
  static const isActive = 'is_active';
  static const vendorProductId = 'vendor_product_id';
  static const store = 'store';
  static const activatedAt = 'activated_at';
  static const renewedAt = 'renewed_at';
  static const expiresAt = 'expires_at';
  static const isLifetime = 'is_lifetime';
  static const activeIntroductoryOfferType = 'active_introductory_offer_type';
  static const activePromotionalOfferType = 'active_promotional_offer_type';
  static const iosActiveDiscountId = 'active_promotional_offer_id';
  static const androidActiveOfferId = 'offer_id';

  static const willRenew = 'will_renew';
  static const isInGracePeriod = 'is_in_grace_period';
  static const unsubscribedAt = 'unsubscribed_at';
  static const billingIssueDetectedAt = 'billing_issue_detected_at';
  static const startsAt = 'starts_at';
  static const cancellationReason = 'cancellation_reason';
  static const isRefund = 'is_refund';
}

extension MapExtension on Map<String, dynamic> {
  Map<String, AdaptyAccessLevel>? accessLevelDictionaryIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;

    return (value as Map).map((key, value) => MapEntry(key, AdaptyAccessLevelJSONBuilder.fromJsonValue(value)));
  }
}
