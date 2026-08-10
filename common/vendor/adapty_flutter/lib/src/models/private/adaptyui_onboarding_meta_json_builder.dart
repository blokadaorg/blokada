// ignore_for_file: deprecated_member_use_from_same_package
part of '../adaptyui/adaptyui_onboarding_meta.dart';

extension AdaptyUIOnboardingMetaJSONBuilder on AdaptyUIOnboardingMeta {
  dynamic get jsonValue => {
        _Keys.onboardingId: onboardingId,
        _Keys.screenClientId: screenClientId,
        _Keys.screenIndex: screenIndex,
        _Keys.screensTotal: screensTotal,
      };

  static AdaptyUIOnboardingMeta fromJsonValue(Map<String, dynamic> json) {
    return AdaptyUIOnboardingMeta(
      onboardingId: json.string(_Keys.onboardingId),
      screenClientId: json.string(_Keys.screenClientId),
      screenIndex: json.integer(_Keys.screenIndex),
      screensTotal: json.integer(_Keys.screensTotal),
    );
  }
}

class _Keys {
  static const onboardingId = 'onboarding_id';
  static const screenClientId = 'screen_cid';
  static const screenIndex = 'screen_index';
  static const screensTotal = 'total_screens';
}
