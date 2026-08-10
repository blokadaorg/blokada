//
//  adapty_period_unit_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_period_unit.dart';

extension AdaptyPeriodUnitJSONBuilder on AdaptyPeriodUnit {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyPeriodUnit.day:
        return _Keys.day;
      case AdaptyPeriodUnit.week:
        return _Keys.week;
      case AdaptyPeriodUnit.month:
        return _Keys.month;
      case AdaptyPeriodUnit.year:
        return _Keys.year;
      case AdaptyPeriodUnit.unknown:
        return _Keys.unknown;
    }
  }

  static AdaptyPeriodUnit fromJsonValue(String json) {
    switch (json) {
      case _Keys.day:
        return AdaptyPeriodUnit.day;
      case _Keys.week:
        return AdaptyPeriodUnit.week;
      case _Keys.month:
        return AdaptyPeriodUnit.month;
      case _Keys.year:
        return AdaptyPeriodUnit.year;
      default:
        return AdaptyPeriodUnit.unknown;
    }
  }
}

class _Keys {
  static const day = 'day';
  static const week = 'week';
  static const month = 'month';
  static const year = "year";
  static const unknown = "unknown";
}

extension MapExtension on Map<String, dynamic> {
  AdaptyPeriodUnit periodUnit(String key) {
    return AdaptyPeriodUnitJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptyPeriodUnit? periodUnitIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyPeriodUnitJSONBuilder.fromJsonValue(value);
  }
}
