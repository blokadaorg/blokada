//
//  adapty_flow_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_flow.dart';

extension AdaptyFlowJSONBuilder on AdaptyFlow {
  dynamic get jsonValue => {
        _Keys.placement: placement.jsonValue,
        _Keys.flowId: instanceIdentity,
        _Keys.flowName: name,
        _Keys.variationId: variationId,
        if (remoteConfigs.isNotEmpty) _Keys.remoteConfigs: remoteConfigs.map((e) => e.jsonValue).toList(growable: false),
        if (_flowVersionId != null) _Keys.flowVersionId: _flowVersionId,
        _Keys.variations: paywalls.map((e) => e.jsonValue).toList(growable: false),
        _Keys.responseCreatedAt: _responseCreatedAt,
        if (_payloadData != null) _Keys.payloadData: _payloadData,
      };

  static AdaptyFlow fromJsonValue(Map<String, dynamic> json) {
    final placement = AdaptyPlacementJSONBuilder.fromJsonValue(json.object(_Keys.placement));
    final remoteConfigs = json[_Keys.remoteConfigs] as List<dynamic>?;
    final variations = json[_Keys.variations] as List<dynamic>?;

    return AdaptyFlow._(
      placement,
      json.string(_Keys.flowId),
      json.string(_Keys.flowName),
      json.string(_Keys.variationId),
      remoteConfigs != null ? remoteConfigs.map((e) => AdaptyRemoteConfigJSONBuilder.fromJsonValue(e as Map<String, dynamic>)).toList(growable: false) : const [],
      variations != null ? variations.map((e) => AdaptyFlowPaywallJSONBuilder.fromJsonValue(e as Map<String, dynamic>, placement)).toList(growable: false) : const [],
      json.stringIfPresent(_Keys.flowVersionId),
      json.integer(_Keys.responseCreatedAt),
      json.stringIfPresent(_Keys.payloadData),
    );
  }
}

class _Keys {
  static const placement = 'placement';
  static const flowId = 'flow_id';
  static const flowName = 'flow_name';
  static const variationId = 'variation_id';
  static const remoteConfigs = 'remote_configs';
  static const flowVersionId = 'flow_version_id';
  static const variations = 'variations';
  static const payloadData = 'payload_data';
  static const responseCreatedAt = 'response_created_at';
}
