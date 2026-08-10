//
//  adapty_subscription_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_subscription.dart';

extension AdaptySubscriptionJSONBuilder on AdaptySubscription {
  static AdaptySubscription fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscription._(
      json.string(_Keys.store),
      json.string(_Keys.vendorProductId),
      json.string(_Keys.vendorTransactionId),
      json.string(_Keys.vendorOriginalTransactionId),
      json.boolean(_Keys.isActive),
      json.boolean(_Keys.isLifetime),
      json.dateTime(_Keys.activatedAt),
      json.dateTimeIfPresent(_Keys.renewedAt),
      json.dateTimeIfPresent(_Keys.expiresAt),
      json.dateTimeIfPresent(_Keys.startsAt),
      json.dateTimeIfPresent(_Keys.unsubscribedAt),
      json.dateTimeIfPresent(_Keys.billingIssueDetectedAt),
      json.boolean(_Keys.isInGracePeriod),
      json.boolean(_Keys.isSandbox),
      json.boolean(_Keys.isRefund),
      json.boolean(_Keys.willRenew),
      json.stringIfPresent(_Keys.activeIntroductoryOfferType),
      json.stringIfPresent(_Keys.activePromotionalOfferType),
      AdaptySDKNative.isIOS ? json.stringIfPresent(_Keys.iosActiveDiscountId) : null,
      AdaptySDKNative.isAndroid ? json.stringIfPresent(_Keys.androidActiveOfferId) : null,
      json.stringIfPresent(_Keys.cancellationReason),
    );
  }
}

class _Keys {
  static const isActive = 'is_active';
  static const vendorProductId = 'vendor_product_id';
  static const vendorTransactionId = 'vendor_transaction_id';
  static const vendorOriginalTransactionId = 'vendor_original_transaction_id';
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
  static const isSandbox = 'is_sandbox';
}

extension MapExtension on Map<String, dynamic> {
  Map<String, AdaptySubscription>? subscriptionIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;

    return (value as Map).map((key, value) => MapEntry(key, AdaptySubscriptionJSONBuilder.fromJsonValue(value)));
  }
}
