// ignore_for_file: deprecated_member_use_from_same_package
part of '../adapty_onboarding.dart';

extension AdaptyOnboardingJSONBuilder on AdaptyOnboarding {
  dynamic get jsonValue => {
        _Keys.placement: placement.jsonValue,
        _Keys.onboardingId: id,
        _Keys.onboardingName: name,
        _Keys.variationId: variationId,
        _Keys.remoteConfig: remoteConfig?.jsonValue,
        _Keys.onboardingBuilder: {
          _Keys.onboardingBuilderConfigUrl: _onboardingBuilderConfigUrl,
        },
        _Keys.payloadData: _payloadData,
        _Keys.responseCreatedAt: _responseCreatedAt,
        _Keys.requestLocale: _requestLocale,
      };

  static AdaptyOnboarding fromJsonValue(Map<String, dynamic> json) {
    final remoteConfig = json.objectIfPresent(_Keys.remoteConfig);
    final onboardingBuilder = json.object(_Keys.onboardingBuilder);

    return AdaptyOnboarding._(
      AdaptyPlacementJSONBuilder.fromJsonValue(json.object(_Keys.placement)),
      json.string(_Keys.onboardingId),
      json.string(_Keys.onboardingName),
      json.string(_Keys.variationId),
      remoteConfig != null ? AdaptyRemoteConfigJSONBuilder.fromJsonValue(remoteConfig) : null,
      json.integer(_Keys.responseCreatedAt),
      onboardingBuilder.string(_Keys.onboardingBuilderConfigUrl),
      json.stringIfPresent(_Keys.payloadData),
      json.string(_Keys.requestLocale),
    );
  }
}

class _Keys {
  static const placement = 'placement';
  static const onboardingId = 'onboarding_id';
  static const onboardingName = 'onboarding_name';
  static const variationId = 'variation_id';
  static const remoteConfig = 'remote_config';
  static const onboardingBuilder = 'onboarding_builder';
  static const onboardingBuilderConfigUrl = 'config_url';
  static const payloadData = 'payload_data';
  static const responseCreatedAt = 'response_created_at';
  static const requestLocale = 'request_locale';
}
