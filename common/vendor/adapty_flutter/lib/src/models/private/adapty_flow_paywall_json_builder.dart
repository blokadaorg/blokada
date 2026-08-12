//
//  adapty_flow_paywall_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_flow_paywall.dart';

extension AdaptyFlowPaywallJSONBuilder on AdaptyFlowPaywall {
  dynamic get jsonValue => {
        _Keys.placement: placement.jsonValue,
        _Keys.paywallId: instanceIdentity,
        _Keys.paywallName: name,
        _Keys.variationId: variationId,
        _Keys.products: _products.map((e) => e.jsonValue).toList(growable: false),
        if (_webPurchaseUrl != null) _Keys.webPurchaseUrl: _webPurchaseUrl,
      };

  /// The variation JSON does not carry its own `placement`: it is a property of
  /// the parent `AdaptyFlow` and is injected here, mirroring the iOS SDK where
  /// `placement` comes from the flow's decoding configuration, not the wire.
  static AdaptyFlowPaywall fromJsonValue(Map<String, dynamic> json, AdaptyPlacement placement) {
    return AdaptyFlowPaywall._(
      placement,
      json.string(_Keys.paywallId),
      json.string(_Keys.paywallName),
      json.string(_Keys.variationId),
      json.productReferenceList(_Keys.products),
      json.stringIfPresent(_Keys.webPurchaseUrl),
    );
  }
}

class _Keys {
  static const placement = 'placement';
  static const paywallId = 'paywall_id';
  static const paywallName = 'paywall_name';
  static const variationId = 'variation_id';
  static const products = 'products';
  static const webPurchaseUrl = 'web_purchase_url';
}
