//
//  adapty_price_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_price.dart';

extension AdaptyPriceJSONBuilder on AdaptyPrice {
  dynamic get jsonValue => {
        _Keys.amount: amount,
        _Keys.currencyCode: currencyCode,
        _Keys.currencySymbol: currencySymbol,
        _Keys.localizedString: localizedString,
      };

  static AdaptyPrice fromJsonValue(Map<String, dynamic> json) {
    return AdaptyPrice._(
      json.float(_Keys.amount),
      json.stringIfPresent(_Keys.currencyCode),
      json.stringIfPresent(_Keys.currencySymbol),
      json.stringIfPresent(_Keys.localizedString),
    );
  }
}

class _Keys {
  static const amount = 'amount';
  static const currencyCode = 'currency_code';
  static const currencySymbol = 'currency_symbol';
  static const localizedString = 'localized_string';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyPrice price(String key) => AdaptyPriceJSONBuilder.fromJsonValue(this[key]);

  AdaptyPrice? priceIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyPriceJSONBuilder.fromJsonValue(value);
  }
}
