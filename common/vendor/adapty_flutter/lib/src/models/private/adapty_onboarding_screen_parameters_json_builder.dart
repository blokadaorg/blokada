// ignore_for_file: deprecated_member_use_from_same_package
//
//  adapty_onboarding_screen_parameters_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_onboarding_screen_parameters.dart';

extension AdaptyOnboardingScreenParametersJSONBuilder on AdaptyOnboardingScreenParameters {
  dynamic get jsonValue => {
        if (name != null) _Keys.name: name,
        if (screenName != null) _Keys.screenName: screenName,
        _Keys.screenOrder: screenOrder,
      };
}

class _Keys {
  static const name = 'onboarding_name';
  static const screenName = 'onboarding_screen_name';
  static const screenOrder = 'onboarding_screen_order';
}
