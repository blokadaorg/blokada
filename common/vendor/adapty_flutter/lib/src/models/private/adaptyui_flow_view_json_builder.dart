part of '../adaptyui/adaptyui_flow_view.dart';

extension AdaptyUIFlowViewJSONBuilder on AdaptyUIFlowView {
  dynamic get jsonValue => {
        _Keys.id: id,
        _Keys.placementId: placementId,
        _Keys.variationId: variationId,
        if (locale != null) _Keys.locale: locale,
      };

  static AdaptyUIFlowView fromJsonValue(Map<String, dynamic> json) {
    return AdaptyUIFlowView._(
      json.string(_Keys.id),
      json.string(_Keys.placementId),
      json.string(_Keys.variationId),
      json.stringIfPresent(_Keys.locale),
    );
  }
}

class _Keys {
  static const id = 'id';
  static const placementId = 'placement_id';
  static const variationId = 'variation_id';
  static const locale = 'locale';
}
