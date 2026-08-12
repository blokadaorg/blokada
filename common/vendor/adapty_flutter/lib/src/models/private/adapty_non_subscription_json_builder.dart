//
//  adapty_non_subscription_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_non_subscription.dart';

extension AdaptyNonSubscriptionJSONBuilder on AdaptyNonSubscription {
  static AdaptyNonSubscription fromJsonValue(Map<String, dynamic> json) {
    return AdaptyNonSubscription._(
      json.string(_Keys.purchaseId),
      json.string(_Keys.store),
      json.string(_Keys.vendorProductId),
      json.stringIfPresent(_Keys.vendorTransactionId),
      json.dateTime(_Keys.purchasedAt),
      json.boolean(_Keys.isSandbox),
      json.boolean(_Keys.isRefund),
      json.boolean(_Keys.isConsumable),
    );
  }
}

class _Keys {
  static const purchaseId = 'purchase_id';
  static const store = 'store';
  static const vendorProductId = 'vendor_product_id';
  static const vendorTransactionId = 'vendor_transaction_id';
  static const purchasedAt = 'purchased_at';
  static const isSandbox = 'is_sandbox';
  static const isRefund = 'is_refund';
  static const isConsumable = 'is_consumable';
}

extension MapExtension on Map<String, dynamic> {
  Map<String, List<AdaptyNonSubscription>>? nonSubscriptionDictionaryIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;

    return (value as Map).map((key, list) => MapEntry(key, (list as List).map((value) => AdaptyNonSubscriptionJSONBuilder.fromJsonValue(value)).toList(growable: false)));
  }
}
