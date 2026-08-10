part of '../adapty_subscription_offer.dart';

extension AdaptySubscriptionOfferJSONBuilder on AdaptySubscriptionOffer {
  dynamic get jsonValue => {
        _Keys.identifier: identifier,
        _Keys.phases: phases.map((e) => e.jsonValue),
      };

  static AdaptySubscriptionOffer fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionOffer._(
      json.subscriptionOfferIdentifier(_Keys.identifier),
      json.subscriptionPhaseList(_Keys.phases),
      json.stringListIfPresent(_Keys.offerTags),
    );
  }
}

class _Keys {
  static const identifier = 'offer_identifier';
  static const phases = 'phases';
  static const offerTags = 'offer_tags';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionOffer? subscriptionOfferIfPresent(String key) {
    return this[key] != null ? AdaptySubscriptionOfferJSONBuilder.fromJsonValue(this[key]) : null;
  }
}
