//
//  adapty_subscription.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'adapty_sdk_native.dart';
import 'private/json_builder.dart';

part 'private/adapty_subscription_json_builder.dart';

@immutable
class AdaptySubscription {
  /// A store of the purchase.
  ///
  /// Possible values:
  /// - `app_store`
  /// - `play_store`
  /// - `adapty`
  final String store;

  /// An identifier of a product in a store that unlocked this subscription.
  final String vendorProductId;

  /// A transaction id of a purchase in a store that unlocked this subscription.
  final String vendorTransactionId;

  /// An original transaction id of the purchase in a store that unlocked this subscription. For auto-renewable subscription, this will be an id of the first transaction in this subscription.
  final String vendorOriginalTransactionId;

  /// True if the subscription is active
  final bool isActive;

  /// True if the subscription is active for a lifetime (no expiration date)
  final bool isLifetime;

  /// Time when the subscription was activated.
  final DateTime activatedAt;

  /// Time when the subscription was renewed. It can be `null` if the purchase was first in chain or it is non-renewing subscription.
  ///
  /// [Nullable]
  final DateTime? renewedAt;

  /// Time when the access level will expire (could be in the past and could be `null` for lifetime access).
  ///
  /// [Nullable]
  final DateTime? expiresAt;

  /// Time when the subscription has started (could be in the future).
  ///
  /// [Nullable]
  final DateTime? startsAt;

  /// Time when the auto-renewable subscription was cancelled. Subscription can still be active, it means that auto-renewal is turned off. Would be `null` if a user reactivates the subscription.
  ///
  /// [Nullable]
  final DateTime? unsubscribedAt;

  /// Time when a billing issue was detected. Subscription can still be active.
  ///
  /// [Nullable]
  final DateTime? billingIssueDetectedAt;

  /// Whether the auto-renewable subscription is in a grace period.
  final bool isInGracePeriod;

  /// `true` if the product was purchased in a sandbox environment.
  final bool isSandbox;

  /// `true` if the purchase was refunded.
  final bool isRefund;

  /// `true` if the auto-renewable subscription is set to renew
  final bool willRenew;

  /// A type of an active introductory offer. If the value is not null, it means that the offer was applied during the current subscription period.
  ///
  /// Possible values:
  /// - `free_trial`
  /// - `pay_as_you_go`
  /// - `pay_up_front`
  ///
  /// [Nullable]
  final String? activeIntroductoryOfferType;

  /// A type of an active promotional offer. If the value is not null, it means that the offer was applied during the current subscription period.
  ///
  /// Possible values:
  /// - `free_trial`
  /// - `pay_as_you_go`
  /// - `pay_up_front`
  ///
  /// [Nullable]
  final String? activePromotionalOfferType;

  /// An id of active promotional offer.
  ///
  /// [Nullable]
  final String? activePromotionalOfferId;

  /// [Nullable]
  final String? offerId;

  /// A reason why a subscription was cancelled.
  ///
  /// Possible values:
  /// - `voluntarily_cancelled`
  /// - `billing_error`
  /// - `price_increase`
  /// - `product_was_not_available`
  /// - `refund`
  /// - `upgraded`
  /// - `unknown`
  ///
  /// [Nullable]
  final String? cancellationReason;

  const AdaptySubscription._(
    this.store,
    this.vendorProductId,
    this.vendorTransactionId,
    this.vendorOriginalTransactionId,
    this.isActive,
    this.isLifetime,
    this.activatedAt,
    this.renewedAt,
    this.expiresAt,
    this.startsAt,
    this.unsubscribedAt,
    this.billingIssueDetectedAt,
    this.isInGracePeriod,
    this.isSandbox,
    this.isRefund,
    this.willRenew,
    this.activeIntroductoryOfferType,
    this.activePromotionalOfferType,
    this.activePromotionalOfferId,
    this.offerId,
    this.cancellationReason,
  );

  @override
  String toString() => '(store: $store, '
      'vendorProductId: $vendorProductId, '
      'vendorTransactionId: $vendorTransactionId, '
      'vendorOriginalTransactionId: $vendorOriginalTransactionId, '
      'isActive: $isActive, '
      'isLifetime: $isLifetime, '
      'activatedAt: $activatedAt, '
      'renewedAt: $renewedAt, '
      'expiresAt: $expiresAt, '
      'startsAt: $startsAt, '
      'unsubscribedAt: $unsubscribedAt, '
      'billingIssueDetectedAt: $billingIssueDetectedAt, '
      'isInGracePeriod: $isInGracePeriod, '
      'isSandbox: $isSandbox, '
      'isRefund: $isRefund, '
      'willRenew: $willRenew, '
      'activeIntroductoryOfferType: $activeIntroductoryOfferType, '
      'activePromotionalOfferType: $activePromotionalOfferType, '
      'activePromotionalOfferId: $activePromotionalOfferId, '
      'offerId: $offerId, '
      'cancellationReason: $cancellationReason)';
}
