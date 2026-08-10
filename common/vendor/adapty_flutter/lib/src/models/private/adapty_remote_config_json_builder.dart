part of '../adapty_remote_config.dart';

extension AdaptyRemoteConfigJSONBuilder on AdaptyRemoteConfig {
  dynamic get jsonValue => {
        _Keys.locale: locale,
        _Keys.data: data,
      };

  static AdaptyRemoteConfig fromJsonValue(Map<String, dynamic> json) {
    return AdaptyRemoteConfig._(
      json.string(_Keys.locale),
      json.string(_Keys.data),
    );
  }
}

class _Keys {
  static const locale = 'lang';
  static const data = 'data';
}
