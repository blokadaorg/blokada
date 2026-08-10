// ignore_for_file: deprecated_member_use_from_same_package
part of '../adaptyui/adaptyui_onboarding_view.dart';

extension AdaptyUIOnboardingViewJSONBuilder on AdaptyUIOnboardingView {
  dynamic get jsonValue => {
        _Keys.id: id,
        _Keys.placementId: placementId,
        _Keys.variationId: variationId,
      };

  static AdaptyUIOnboardingView fromJsonValue(Map<String, dynamic> json) {
    return AdaptyUIOnboardingView._(
      json.string(_Keys.id),
      json.string(_Keys.placementId),
      json.string(_Keys.variationId),
    );
  }
}

class _Keys {
  static const id = 'id';
  static const placementId = 'placement_id';
  static const variationId = 'variation_id';
}
