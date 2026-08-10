//
//  adapty_product_subscription_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

part of '../adapty_product_subscription.dart';

extension AdaptyProductSubscriptionJSONBuilder on AdaptyProductSubscription {
  static AdaptyProductSubscription fromJsonValue(Map<String, dynamic> json) {
    return AdaptyProductSubscription._(
      json.stringIfPresent(_Keys.groupIdentifier),
      json.subscriptionPeriod(_Keys.period),
      json.stringIfPresent(_Keys.localizedPeriod),
      json.subscriptionOfferIfPresent(_Keys.offer),
      json.renewalTypeIfPresent(_Keys.renewalType) ?? AdaptyRenewalType.autorenewable,
      json.stringIfPresent(_Keys.basePlanId),
    );
  }
}

class _Keys {
  static const groupIdentifier = 'group_identifier';
  static const period = 'period';
  static const localizedPeriod = 'localized_period';
  static const offer = 'offer';
  static const renewalType = 'renewal_type';
  static const basePlanId = 'base_plan_id';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyProductSubscription? productSubscriptionIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyProductSubscriptionJSONBuilder.fromJsonValue(value);
  }
}
