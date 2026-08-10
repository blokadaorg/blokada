//
//  adapty_paywall_product_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_paywall_product.dart';

extension AdaptyPaywallProductJSONBuilder on AdaptyPaywallProduct {
  dynamic get jsonValue => {
        _Keys.vendorProductId: vendorProductId,
        if (flowProductId != null) _Keys.flowProductId: flowProductId,
        _Keys.adaptyProductId: _adaptyProductId,
        _Keys.paywallVariationId: paywallVariationId,
        _Keys.paywallABTestName: paywallABTestName,
        _Keys.paywallName: paywallName,
        if (subscription?.offer?.identifier != null) _Keys.subscriptionOfferIdentifier: subscription!.offer!.identifier.jsonValue,
        _Keys.paywallProductIndex: paywallProductIndex,
        _Keys.accessLevelId: accessLevelId,
        _Keys.productType: productType,
        _Keys.localizedDescription: localizedDescription,
        _Keys.localizedTitle: localizedTitle,
        if (regionCode != null) _Keys.regionCode: regionCode,
        _Keys.isFamilyShareable: isFamilyShareable,
        _Keys.price: price.jsonValue,
        if (_payloadData != null) _Keys.payloadData: _payloadData,
        if (_webPurchaseUrl != null) _Keys.webPurchaseUrl: _webPurchaseUrl,
      };

  static AdaptyPaywallProduct fromJsonValue(Map<String, dynamic> json) {
    return AdaptyPaywallProduct._(
      json.string(_Keys.vendorProductId),
      json.stringIfPresent(_Keys.flowProductId),
      json.string(_Keys.adaptyProductId),
      json.string(_Keys.accessLevelId),
      json.string(_Keys.productType),
      json.string(_Keys.localizedDescription),
      json.string(_Keys.localizedTitle),
      json.stringIfPresent(_Keys.regionCode),
      json.booleanIfPresent(_Keys.isFamilyShareable) ?? false,
      json.string(_Keys.paywallVariationId),
      json.string(_Keys.paywallABTestName),
      json.string(_Keys.paywallName),
      json.price(_Keys.price),
      json.productSubscriptionIfPresent(_Keys.subscription),
      json.stringIfPresent(_Keys.payloadData),
      json.integer(_Keys.paywallProductIndex),
      json.stringIfPresent(_Keys.webPurchaseUrl),
    );
  }
}

class _Keys {
  static const vendorProductId = 'vendor_product_id';
  static const flowProductId = 'flow_product_id';
  static const adaptyProductId = 'adapty_product_id';
  static const accessLevelId = 'access_level_id';
  static const productType = 'product_type';
  static const paywallVariationId = 'paywall_variation_id';
  static const paywallABTestName = 'paywall_ab_test_name';
  static const paywallName = 'paywall_name';
  static const localizedDescription = "localized_description";
  static const localizedTitle = "localized_title";
  static const isFamilyShareable = "is_family_shareable";
  static const regionCode = "region_code";
  static const price = 'price';
  static const subscription = 'subscription';
  static const payloadData = 'payload_data';

  static const subscriptionOfferIdentifier = 'subscription_offer_identifier';
  static const paywallProductIndex = 'paywall_product_index';
  static const webPurchaseUrl = 'web_purchase_url';
}
