//
//  adapty_profile_parameters_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'adapty_ios_app_tracking_transparency_status.dart';
import 'adapty_profile_gender.dart';
import 'adapty_profile_parameters.dart';

class AdaptyProfileParametersBuilder {
  var _parameters = AdaptyProfileParameters();
  void setFirstName(String? value) => _parameters.firstName = value;
  void setLastName(String? value) => _parameters.lastName = value;
  void setGender(AdaptyProfileGender? value) => _parameters.gender = value;
  void setBirthday(DateTime? value) => _parameters.birthday = value;
  void setEmail(String? value) => _parameters.email = value;
  void setPhoneNumber(String? value) => _parameters.phoneNumber = value;
  void setAppTrackingTransparencyStatus(AdaptyIOSAppTrackingTransparencyStatus? value) => _parameters.appTrackingTransparencyStatus = value;
  void setAnalyticsDisabled(bool? value) => _parameters.analyticsDisabled = value;
  void setCustomStringAttribute(String value, String key) => _parameters.setCustomStringAttribute(value, key);
  void setCustomDoubleAttribute(double value, String key) => _parameters.setCustomDoubleAttribute(value, key);
  void removeCustomAttribute(String key) => _parameters.removeCustomAttribute(key);
  AdaptyProfileParameters build() => _parameters;
}
