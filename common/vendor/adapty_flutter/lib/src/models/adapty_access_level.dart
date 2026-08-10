//
//  adapty_access_level.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'adapty_sdk_native.dart';
import 'private/json_builder.dart';

part 'private/adapty_access_level_json_builder.dart';

@immutable
class AdaptyAccessLevel {
  /// Unique identifier of the access level configured by you in Adapty Dashboard.
  final String id;

  /// `true` if this access level is active. Generally, you can check this property to determine wether a user has an access to premium features.
  final bool isActive;

  /// An identifier of a product in a store that unlocked this access level.
  final String vendorProductId;

  /// A store of the purchase that unlocked this access level.
  ///
  /// Possible values:
  /// - `app_store`
  /// - `play_store`
  /// - `adapty`
  final String store;

  /// Time when this access level was activated.
  final DateTime activatedAt;

  /// Time when the access level was renewed. It can be `null` if the purchase was first in chain or it is non-renewing subscription / non-consumable (e.g. lifetime)
  ///
  /// [Nullable]
  final DateTime? renewedAt;

  /// Time when the access level will expire (could be in the past and could be `null` for lifetime access).
  ///
  /// [Nullable]
  final DateTime? expiresAt;

  /// `true` if this access level is active for a lifetime (no expiration date).
  final bool isLifetime;

  /// A type of an active introductory offer. If the value is not `null`, it means that the offer was applied during the current subscription period.
  ///
  /// Possible values:
  /// - `free_trial`
  /// - `pay_as_you_go`
  /// - `pay_up_front`
  final String? activeIntroductoryOfferType;

  ///  A type of an active promotional offer. If the value is not `null`, it means that the offer was applied during the current subscription period.
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

  /// `true` if this auto-renewable subscription is set to renew.
  final bool willRenew;

  /// `true` if this auto-renewable subscription is in the grace period.
  final bool isInGracePeriod;

  /// Time when the auto-renewable subscription was cancelled. Subscription can still be active, it just means that auto-renewal turned off.
  /// Will be set to `null` if the user reactivates the subscription.
  ///
  /// [Nullable]
  final DateTime? unsubscribedAt;

  /// Time when billing issue was detected. Subscription can still be active. Would be set to null if a charge is made.
  ///
  /// [Nullable]
  final DateTime? billingIssueDetectedAt;

  /// Time when this access level has started (could be in the future).
  ///
  /// [Nullable]
  final DateTime? startsAt;

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

  /// `true` if this purchase was refunded
  final bool isRefund;

  const AdaptyAccessLevel._(
    this.id,
    this.isActive,
    this.vendorProductId,
    this.store,
    this.activatedAt,
    this.renewedAt,
    this.expiresAt,
    this.isLifetime,
    this.activeIntroductoryOfferType,
    this.activePromotionalOfferType,
    this.activePromotionalOfferId,
    this.offerId,
    this.willRenew,
    this.isInGracePeriod,
    this.unsubscribedAt,
    this.billingIssueDetectedAt,
    this.startsAt,
    this.cancellationReason,
    this.isRefund,
  );

  @override
  String toString() => '(id: $id, '
      'isActive: $isActive, '
      'vendorProductId: $vendorProductId, '
      'store: $store, '
      'activatedAt: $activatedAt, '
      'renewedAt: $renewedAt, '
      'expiresAt: $expiresAt, '
      'isLifetime: $isLifetime, '
      'activeIntroductoryOfferType: $activeIntroductoryOfferType, '
      'activePromotionalOfferType: $activePromotionalOfferType, '
      'activePromotionalOfferId: $activePromotionalOfferId, '
      'offerId: $offerId, '
      'willRenew: $willRenew, '
      'isInGracePeriod: $isInGracePeriod, '
      'unsubscribedAt: $unsubscribedAt, '
      'billingIssueDetectedAt: $billingIssueDetectedAt, '
      'startsAt: $startsAt, '
      'cancellationReason: $cancellationReason, '
      'isRefund: $isRefund)';
}
