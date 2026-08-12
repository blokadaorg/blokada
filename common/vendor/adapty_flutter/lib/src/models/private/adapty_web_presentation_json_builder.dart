//
//  adapty_web_presentation_json_builder.dart
//  Adapty
//
//  Created on 2024.
//

part of '../adapty_web_presentation.dart';

extension AdaptyWebPresentationJSONBuilder on AdaptyWebPresentation {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyWebPresentation.externalBrowser:
        return _Keys.externalBrowser;
      case AdaptyWebPresentation.inAppBrowser:
        return _Keys.inAppBrowser;
    }
  }

  static AdaptyWebPresentation fromJsonValue(String json) {
    switch (json) {
      case _Keys.externalBrowser:
        return AdaptyWebPresentation.externalBrowser;
      case _Keys.inAppBrowser:
        return AdaptyWebPresentation.inAppBrowser;
      default:
        return AdaptyWebPresentation.externalBrowser;
    }
  }
}

class _Keys {
  static const externalBrowser = 'browser_out_app';
  static const inAppBrowser = 'browser_in_app';
}
