//
//  adapty_non_subscription.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'private/json_builder.dart';

part 'private/adapty_non_subscription_json_builder.dart';

@immutable
class AdaptyNonSubscription {
  /// An identifier of the purchase in Adapty.
  /// You can use it to ensure that you've already processed this purchase (for example tracking one time products).
  final String purchaseId;

  /// A store of the purchase.
  ///
  /// Possible values:
  /// - `app_store`
  /// - `play_store`
  /// - `adapty`
  final String store;

  /// An identifier of a product in a store that unlocked this subscription.
  final String vendorProductId;

  /// A transaction id of a purchase in a store that unlocked this subscription.
  ///
  /// [Nullable]
  final String? vendorTransactionId;

  /// Date when the product was purchased.
  final DateTime purchasedAt;

  /// `true` if the product was purchased in a sandbox environment.
  final bool isSandbox;

  /// `true` if the purchase was refunded.
  final bool isRefund;

  /// `true` if the product is consumable (should only be processed once).
  final bool isConsumable;

  const AdaptyNonSubscription._(
    this.purchaseId,
    this.store,
    this.vendorProductId,
    this.vendorTransactionId,
    this.purchasedAt,
    this.isSandbox,
    this.isRefund,
    this.isConsumable,
  );

  @override
  String toString() => '(purchaseId: $purchaseId, '
      'store: $store, '
      'vendorProductId: $vendorProductId, '
      'vendorTransactionId: $vendorTransactionId, '
      'purchasedAt: $purchasedAt, '
      'isSandbox: $isSandbox, '
      'isRefund: $isRefund, '
      'isConsumable: $isConsumable)';
}
