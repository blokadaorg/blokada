//
//  adapty_subscription_details.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

import 'package:meta/meta.dart' show immutable;

import 'adapty_renewal_type.dart';
import 'private/json_builder.dart';
import 'adapty_subscription_period.dart';
import 'adapty_subscription_offer.dart';

part 'private/adapty_product_subscription_json_builder.dart';

@immutable
class AdaptyProductSubscription {
  /// The identifier of the subscription group to which the subscription belongs. (Will be `nil` for iOS version below 12.0 and macOS version below 10.14).
  /// iOS Only.
  final String? groupIdentifier;

  final AdaptySubscriptionPeriod period;

  final String? localizedPeriod;

  final AdaptySubscriptionOffer? offer;

  /// The type of the subscription renewal
  final AdaptyRenewalType renewalType;

  /// The identifier of the base plan. Android Only.
  final String? basePlanId;

  const AdaptyProductSubscription._(
    this.groupIdentifier,
    this.period,
    this.localizedPeriod,
    this.offer,
    this.renewalType,
    this.basePlanId,
  );

  @override
  String toString() => '(groupIdentifier: $groupIdentifier, '
      'period: $period, '
      'localizedPeriod: $localizedPeriod, '
      'offer: $offer, '
      'renewalType: $renewalType, '
      'basePlanId: $basePlanId)';
}
