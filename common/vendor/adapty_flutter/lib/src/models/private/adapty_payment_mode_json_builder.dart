//
//  adapty_payment_mode_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_payment_mode.dart';

extension AdaptyPaymentModeJSONBuilder on AdaptyPaymentMode {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyPaymentMode.payAsYouGo:
        return _Keys.payAsYouGo;
      case AdaptyPaymentMode.payUpFront:
        return _Keys.payUpFront;
      case AdaptyPaymentMode.freeTrial:
        return _Keys.freeTrial;
      case AdaptyPaymentMode.unknown:
        return _Keys.unknown;
    }
  }

  static AdaptyPaymentMode fromJsonValue(String json) {
    switch (json) {
      case _Keys.payAsYouGo:
        return AdaptyPaymentMode.payAsYouGo;
      case _Keys.payUpFront:
        return AdaptyPaymentMode.payUpFront;
      case _Keys.freeTrial:
        return AdaptyPaymentMode.freeTrial;
      default:
        return AdaptyPaymentMode.unknown;
    }
  }
}

class _Keys {
  static const payAsYouGo = 'pay_as_you_go';
  static const payUpFront = 'pay_up_front';
  static const freeTrial = 'free_trial';
  static const unknown = "unknown";
}

extension MapExtension on Map<String, dynamic> {
  AdaptyPaymentMode paymentMode(String key) {
    return AdaptyPaymentModeJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptyPaymentMode? paymentModeIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyPaymentModeJSONBuilder.fromJsonValue(value);
  }
}
