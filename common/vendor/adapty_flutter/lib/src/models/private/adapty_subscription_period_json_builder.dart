//
//  adapty_subscription_period_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//
part of '../adapty_subscription_period.dart';

extension AdaptySubscriptionPeriodJSONBuilder on AdaptySubscriptionPeriod {
  dynamic get jsonValue => {
        _Keys.unit: unit.jsonValue,
        _Keys.numberOfUnits: numberOfUnits,
      };

  static AdaptySubscriptionPeriod fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionPeriod._(json.periodUnit(_Keys.unit), json.integer(_Keys.numberOfUnits));
  }
}

class _Keys {
  static const unit = 'unit';
  static const numberOfUnits = 'number_of_units';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionPeriod subscriptionPeriod(String key) {
    return AdaptySubscriptionPeriodJSONBuilder.fromJsonValue(this[key]);
  }

  AdaptySubscriptionPeriod? subscriptionPeriodIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptySubscriptionPeriodJSONBuilder.fromJsonValue(value);
  }
}
