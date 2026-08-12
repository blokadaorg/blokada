import 'adapty_android_subscription_update_parameters.dart';

part 'private/adapty_purchase_parameters_json_builder.dart';

class AdaptyPurchaseParameters {
  /// Used to upgrade or downgrade a subscription (use for Android).
  AdaptyAndroidSubscriptionUpdateParameters? subscriptionUpdateParams;

  /// Specifies whether the offer is personalized to the buyer (use for Android).
  bool? isOfferPersonalized;

  AdaptyPurchaseParameters({
    this.subscriptionUpdateParams = null,
    this.isOfferPersonalized = null,
  });
}

class AdaptyPurchaseParametersBuilder {
  var _parameters = AdaptyPurchaseParameters();

  void setSubscriptionUpdateParams(AdaptyAndroidSubscriptionUpdateParameters? value) => _parameters.subscriptionUpdateParams = value;

  void setIsOfferPersonalized(bool? value) => _parameters.isOfferPersonalized = value;

  AdaptyPurchaseParameters build() => _parameters;
}
