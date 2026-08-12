import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';
import 'adapty_subscription_phase.dart';
import 'adapty_subscription_offer_identifier.dart';

part 'private/adapty_subscription_offer_json_builder.dart';

@immutable
class AdaptySubscriptionOffer {
  final AdaptySubscriptionOfferIdentifier identifier;

  final List<AdaptySubscriptionPhase> phases;

  final List<String>? offerTags;

  const AdaptySubscriptionOffer._(
    this.identifier,
    this.phases,
    this.offerTags,
  );
}
