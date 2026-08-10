//
//  adapty_ios_app_tracking_transparency_status_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_ios_app_tracking_transparency_status.dart';

extension AdaptyIOSAppTrackingTransparencyStatusJSONBuilder on AdaptyIOSAppTrackingTransparencyStatus {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyIOSAppTrackingTransparencyStatus.notDetermined:
        return _Keys.notDetermined;
      case AdaptyIOSAppTrackingTransparencyStatus.restricted:
        return _Keys.restricted;
      case AdaptyIOSAppTrackingTransparencyStatus.denied:
        return _Keys.denied;
      case AdaptyIOSAppTrackingTransparencyStatus.authorized:
        return _Keys.authorized;
    }
  }
}

class _Keys {
  static const notDetermined = 'not_determined';
  static const restricted = 'restricted';
  static const denied = 'denied';
  static const authorized = 'authorized';
}
