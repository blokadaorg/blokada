//
//  adapty_flow.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';
import 'adapty_flow_paywall.dart';
import 'adapty_remote_config.dart';
import 'adapty_placement.dart';
import 'adapty_product_identifier.dart';

part 'private/adapty_flow_json_builder.dart';

@immutable
class AdaptyFlow {
  /// An `AdaptyPlacement` object, that contains information about the placement of the flow.
  final AdaptyPlacement placement;

  /// An identifier of a flow, configured in Adapty Dashboard.
  final String instanceIdentity;

  /// A flow name.
  final String name;

  /// An identifier of a variation, used to attribute purchases to this flow.
  final String variationId;

  /// Custom dictionaries configured in Adapty Dashboard for this flow.
  final List<AdaptyRemoteConfig> remoteConfigs;

  /// The paywall variations embedded in this flow.
  final List<AdaptyFlowPaywall> paywalls;

  /// If `true`, it is possible to use Adapty Paywall Builder.
  /// Read more here: https://docs.adapty.io/docs/paywall-builder-getting-started
  bool get hasViewConfiguration => _flowVersionId != null;

  final String? _flowVersionId;
  final int _responseCreatedAt;
  final String? _payloadData;

  /// The first remote config of the flow, if present.
  AdaptyRemoteConfig? get remoteConfig => remoteConfigs.isNotEmpty ? remoteConfigs.first : null;

  /// Array of related product identifiers, collected from all paywall variations.
  List<AdaptyProductIdentifier> get productIdentifiers {
    return paywalls
        .expand((variation) => variation.productIdentifiers)
        .toList(growable: false);
  }

  const AdaptyFlow._(
    this.placement,
    this.instanceIdentity,
    this.name,
    this.variationId,
    this.remoteConfigs,
    this.paywalls,
    this._flowVersionId,
    this._responseCreatedAt,
    this._payloadData,
  );

  @override
  String toString() => '(placement: $placement, '
      'instanceIdentity: $instanceIdentity, '
      'name: $name, '
      'variationId: $variationId, '
      'hasViewConfiguration: $hasViewConfiguration, '
      'remoteConfigs: $remoteConfigs, '
      'variations: $paywalls, '
      '_flowVersionId: $_flowVersionId, '
      '_responseCreatedAt: $_responseCreatedAt, '
      '_payloadData: $_payloadData)';
}
