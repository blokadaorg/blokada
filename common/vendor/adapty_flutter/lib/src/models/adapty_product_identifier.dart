import 'package:meta/meta.dart' show immutable;

import 'adapty_purchase_parameters.dart';

@immutable
class AdaptyProductIdentifier {
  final String vendorProductId;

  final String? basePlanId;

  final String _adaptyProductId;

  const AdaptyProductIdentifier({
    required this.vendorProductId,
    this.basePlanId,
    required String adaptyProductId,
  }) : _adaptyProductId = adaptyProductId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AdaptyProductIdentifier && runtimeType == other.runtimeType && vendorProductId == other.vendorProductId && basePlanId == other.basePlanId && _adaptyProductId == other._adaptyProductId;

  @override
  int get hashCode => Object.hash(vendorProductId, basePlanId, _adaptyProductId);

  @override
  String toString() => '(vendorProductId: $vendorProductId, '
      'basePlanId: $basePlanId, '
      '_adaptyProductId: $_adaptyProductId)';

  static Map<String, dynamic> convertProductPurchaseParamsToJson(
    Map<AdaptyProductIdentifier, AdaptyPurchaseParameters>? productPurchaseParams,
  ) {
    if (productPurchaseParams == null) return {};

    return productPurchaseParams.map((key, value) {
      return MapEntry(key._adaptyProductId, value.jsonValue);
    });
  }
}
