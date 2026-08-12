//
//  adapty_renewal_type_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 21.07.2023.
//

part of '../adapty_renewal_type.dart';

extension AdaptyRenewalTypeJSONBuilder on AdaptyRenewalType {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyRenewalType.prepaid:
        return _Keys.prepaid;
      case AdaptyRenewalType.autorenewable:
        return _Keys.autorenewable;
    }
  }

  static AdaptyRenewalType fromJsonValue(String json) {
    switch (json) {
      case _Keys.prepaid:
        return AdaptyRenewalType.prepaid;
      case _Keys.autorenewable:
        return AdaptyRenewalType.autorenewable;
      default:
        return AdaptyRenewalType.autorenewable;
    }
  }
}

class _Keys {
  static const prepaid = 'prepaid';
  static const autorenewable = 'autorenewable';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyRenewalType renewalType(String key) {
    return AdaptyRenewalTypeJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptyRenewalType? renewalTypeIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyRenewalTypeJSONBuilder.fromJsonValue(value);
  }
}
