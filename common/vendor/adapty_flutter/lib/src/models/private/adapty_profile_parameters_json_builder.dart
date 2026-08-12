//
//  adapty_profile_parameters_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_profile_parameters.dart';

extension AdaptyProfileParametersJSONBuilder on AdaptyProfileParameters {
  dynamic get jsonValue => {
        if (firstName != null) _Keys.firstName: firstName,
        if (lastName != null) _Keys.lastName: lastName,
        if (gender != null) _Keys.gender: gender?.jsonValue,
        if (birthday != null) _Keys.birthday: birthday?.toString().substring(0, 10),
        if (email != null) _Keys.email: email,
        if (phoneNumber != null) _Keys.phoneNumber: phoneNumber,
        if (AdaptySDKNative.isIOS && appTrackingTransparencyStatus != null) _Keys.appTrackingTransparencyStatus: appTrackingTransparencyStatus?.jsonValue,
        if (_customAttributes.isNotEmpty) _Keys.customAttributes: _customAttributes,
        if (analyticsDisabled != null) _Keys.analyticsDisabled: analyticsDisabled,
      };
}

class _Keys {
  static const firstName = 'first_name';
  static const lastName = 'last_name';
  static const gender = 'gender';
  static const birthday = 'birthday';
  static const email = 'email';
  static const phoneNumber = 'phone_number';
  static const appTrackingTransparencyStatus = 'att_status';
  static const customAttributes = 'custom_attributes';
  static const analyticsDisabled = 'analytics_disabled';
}
