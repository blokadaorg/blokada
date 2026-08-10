//
//  adapty_android_subscription_update_parameters_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_android_subscription_update_parameters.dart';

extension AdaptyAndroidSubscriptionUpdateParametersJSONBuilder on AdaptyAndroidSubscriptionUpdateParameters {
  dynamic get jsonValue => {
        _Keys.oldSubVendorProductId: oldSubVendorProductId,
        _Keys.replacementMode: replacementMode.jsonValue,
      };
}

class _Keys {
  static const oldSubVendorProductId = 'old_sub_vendor_product_id';
  static const replacementMode = 'replacement_mode';
}
