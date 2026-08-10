part of '../adapty_subscription_offer_identifier.dart';

extension AdaptySubscriptionOfferIdentifierJSONBuilder on AdaptySubscriptionOfferIdentifier {
  dynamic get jsonValue => {
        _Keys.id: id,
        _Keys.type: type.jsonValue,
      };

  static AdaptySubscriptionOfferIdentifier fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionOfferIdentifier._(
      json.stringIfPresent(_Keys.id),
      AdaptySubscriptionOfferTypeJSONBuilder.fromJsonValue(json.string(_Keys.type)),
    );
  }
}

extension AdaptySubscriptionOfferTypeJSONBuilder on AdaptySubscriptionOfferType {
  // Wire values match the native SDKs (iOS `AdaptySubscriptionOfferType`);
  // note the snake_case `win_back`, which does NOT equal the Dart enum name.
  String get jsonValue {
    switch (this) {
      case AdaptySubscriptionOfferType.introductory:
        return 'introductory';
      case AdaptySubscriptionOfferType.promotional:
        return 'promotional';
      case AdaptySubscriptionOfferType.winBack:
        return 'win_back';
      case AdaptySubscriptionOfferType.code:
        return 'code';
    }
  }

  static AdaptySubscriptionOfferType fromJsonValue(String value) {
    switch (value) {
      case 'introductory':
        return AdaptySubscriptionOfferType.introductory;
      case 'promotional':
        return AdaptySubscriptionOfferType.promotional;
      case 'win_back':
        return AdaptySubscriptionOfferType.winBack;
      case 'code':
        return AdaptySubscriptionOfferType.code;
      default:
        return AdaptySubscriptionOfferType.introductory;
    }
  }
}

class _Keys {
  static const id = 'id';
  static const type = 'type';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionOfferIdentifier subscriptionOfferIdentifier(String key) {
    var value = this[key];
    return AdaptySubscriptionOfferIdentifierJSONBuilder.fromJsonValue(value);
  }
}
