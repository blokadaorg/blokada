import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';

part 'private/adapty_subscription_offer_identifier_json_builder.dart';

enum AdaptySubscriptionOfferType {
  introductory,
  promotional,
  winBack,
  code,
}

@immutable
class AdaptySubscriptionOfferIdentifier {
  final String? id;
  final AdaptySubscriptionOfferType type;

  const AdaptySubscriptionOfferIdentifier._(this.id, this.type);
}
