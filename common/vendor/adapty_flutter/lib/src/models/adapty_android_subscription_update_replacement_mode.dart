//
//  adapty_android_subscription_update_replacement_mode.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part 'private/adapty_android_subscription_update_replacement_mode_json_builder.dart';

enum AdaptyAndroidSubscriptionUpdateReplacementMode {
  withTimeProration,
  chargeProratedPrice,
  withoutProration,
  deferred,
  chargeFullPrice,
}