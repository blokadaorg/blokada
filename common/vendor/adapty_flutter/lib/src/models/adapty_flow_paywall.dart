//
//  adapty_flow_paywall.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';
import 'product_reference.dart';
import 'adapty_placement.dart';
import 'adapty_product_identifier.dart';

part 'private/adapty_flow_paywall_json_builder.dart';

@immutable
class AdaptyFlowPaywall {
  /// An `AdaptyPlacement` object, that contains information about the placement of the paywall.
  final AdaptyPlacement placement;

  /// An identifier of a paywall, configured in Adapty Dashboard.
  final String instanceIdentity;

  /// A paywall name.
  final String name;

  /// An identifier of a variation, used to attribute purchases to this paywall.
  final String variationId;

  final List<ProductReference> _products;

  final String? _webPurchaseUrl;

  /// Array of related product identifiers.
  List<AdaptyProductIdentifier> get productIdentifiers {
    return _products
        .map((e) => e.toAdaptyProductIdentifier())
        .toList(growable: false);
  }

  const AdaptyFlowPaywall._(
    this.placement,
    this.instanceIdentity,
    this.name,
    this.variationId,
    this._products,
    this._webPurchaseUrl,
  );

  @override
  String toString() => '(placement: $placement, '
      'instanceIdentity: $instanceIdentity, '
      'name: $name, '
      'variationId: $variationId, '
      '_products: $_products, '
      '_webPurchaseUrl: $_webPurchaseUrl)';
}
