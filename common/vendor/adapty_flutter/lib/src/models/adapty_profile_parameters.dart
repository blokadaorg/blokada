//
//  adapty_profile_parameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'adapty_error.dart';
import 'adapty_error_code.dart';
import 'adapty_ios_app_tracking_transparency_status.dart';
import 'adapty_profile_gender.dart';
import 'adapty_sdk_native.dart';

part 'private/adapty_profile_parameters_json_builder.dart';

class AdaptyProfileParameters {
  String? firstName;
  String? lastName;
  AdaptyProfileGender? gender;
  DateTime? birthday;
  String? email;
  String? phoneNumber;
  AdaptyIOSAppTrackingTransparencyStatus? appTrackingTransparencyStatus;
  bool? analyticsDisabled;

  var _customAttributes = <String, dynamic>{};
  Map<String, dynamic> get customAttributes => _customAttributes;

  void setCustomStringAttribute(String value, String key) {
    if (value.isEmpty || value.length > 50) {
      throw AdaptyError(
        "The value must not be empty and not more than 50 characters.",
        AdaptyErrorCode.wrongParam,
        "AdaptyError.wrongParam(The value must not be empty and not more than 50 characters.)",
      );
    }
    if (!_validateCustomAttributeKey(key, true)) {
      return;
    }
    customAttributes[key] = value;
  }

  void setCustomDoubleAttribute(double value, String key) {
    if (!_validateCustomAttributeKey(key, true)) {
      return;
    }
    customAttributes[key] = value;
  }

  void removeCustomAttribute(String key) {
    if (!_validateCustomAttributeKey(key, false)) {
      return;
    }
    customAttributes[key] = null;
  }

  bool _validateCustomAttributeKey(String addingKey, bool testCount) {
    if (addingKey.isEmpty || addingKey.length > 30 || !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(addingKey)) {
      throw AdaptyError(
        "The key must be string not more than 30 characters. Only letters, numbers, dashes, points and underscores allowed",
        AdaptyErrorCode.wrongParam,
        "AdaptyError.wrongParam(The key must be string not more than 30 characters. Only letters, numbers, dashes, points and underscores allowed)",
      );
    }

    if (!testCount) {
      return true;
    }

    var count = 1;
    _customAttributes.forEach((key, value) {
      if (value != null && key != addingKey) {
        count += 1;
      }
    });

    if (count > 30) {
      throw AdaptyError(
        "The total number of custom attributes must be no more than 30",
        AdaptyErrorCode.wrongParam,
        "AdaptyError.wrongParam(The total number of custom attributes must be no more than 30)",
      );
    }

    return true;
  }
}
