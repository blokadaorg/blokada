//
//  adapty_android_subscription_update_replacement_mode_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_android_subscription_update_replacement_mode.dart';

extension AdaptyAndroidSubscriptionUpdateReplacementModeJSONBuilder on AdaptyAndroidSubscriptionUpdateReplacementMode {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyAndroidSubscriptionUpdateReplacementMode.withTimeProration:
        return _Keys.withTimeProration;
      case AdaptyAndroidSubscriptionUpdateReplacementMode.chargeProratedPrice:
        return _Keys.chargeProratedPrice;
      case AdaptyAndroidSubscriptionUpdateReplacementMode.withoutProration:
        return _Keys.withoutProration;
      case AdaptyAndroidSubscriptionUpdateReplacementMode.deferred:
        return _Keys.deferred;
      case AdaptyAndroidSubscriptionUpdateReplacementMode.chargeFullPrice:
        return _Keys.chargeFullPrice;
    }
  }
}

class _Keys {
  static const String withTimeProration = "with_time_proration";
  static const String chargeProratedPrice = "charge_prorated_price";
  static const String withoutProration = "without_proration";
  static const String deferred = "deferred";
  static const String chargeFullPrice = "charge_full_price";
}
