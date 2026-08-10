//
//  product_reference.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';
import 'adapty_sdk_native.dart';
import 'adapty_product_identifier.dart';

part 'private/product_reference_json_builder.dart';

@immutable
class ProductReference {
  final String? flowProductId;
  final String vendorId;
  final String _adaptyProductId;
  final String accessLevelId;
  final String productType;

  final String? promotionalOfferId; // iOS Only
  final String? winBackOfferId; // iOS Only
  final String? basePlanId; // Android Only
  final String? offerId; // Android Only

  const ProductReference._(
    this.flowProductId,
    this.vendorId,
    this._adaptyProductId,
    this.accessLevelId,
    this.productType,
    this.promotionalOfferId,
    this.winBackOfferId,
    this.basePlanId,
    this.offerId,
  );

  AdaptyProductIdentifier toAdaptyProductIdentifier() {
    return AdaptyProductIdentifier(
      vendorProductId: vendorId,
      basePlanId: basePlanId,
      adaptyProductId: _adaptyProductId,
    );
  }

  String toString() => '(flowProductId: $flowProductId, '
      'vendorId: $vendorId, '
      '_adaptyProductId: $_adaptyProductId, '
      'accessLevelId: $accessLevelId, '
      'productType: $productType, '
      'promotionalOfferId: $promotionalOfferId, '
      'winBackOfferId: $winBackOfferId, '
      'basePlanId: $basePlanId, '
      'offerId: $offerId)';
}
