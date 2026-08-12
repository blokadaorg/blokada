//
//  adapty_log_level_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_log_level.dart';

extension AdaptyLogLevelJSONBuilder on AdaptyLogLevel {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyLogLevel.error:
        return _Keys.error;
      case AdaptyLogLevel.warn:
        return _Keys.warn;
      case AdaptyLogLevel.info:
        return _Keys.info;
      case AdaptyLogLevel.verbose:
        return _Keys.verbose;
      case AdaptyLogLevel.debug:
        return _Keys.debug;
    }
  }

  static AdaptyLogLevel fromJsonValue(String json) {
    switch (json) {
      case _Keys.error:
        return AdaptyLogLevel.error;
      case _Keys.warn:
        return AdaptyLogLevel.warn;
      case _Keys.info:
        return AdaptyLogLevel.info;
      case _Keys.verbose:
        return AdaptyLogLevel.verbose;
      case _Keys.debug:
        return AdaptyLogLevel.debug;
      default:
        throw FormatException("Unknown AdaptyLogLevel value == $json");
    }
  }
}

class _Keys {
  static const error = 'error';
  static const warn = 'warn';
  static const info = 'info';
  static const verbose = "verbose";
  static const debug = "debug";
}

extension MapExtension on Map<String, dynamic> {
  AdaptyLogLevel logLevel(String key) {
    return AdaptyLogLevelJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptyLogLevel? logLevelIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyLogLevelJSONBuilder.fromJsonValue(value);
  }
}
