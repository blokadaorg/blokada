//
//  adapty_subscription_period.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//
import 'package:meta/meta.dart' show immutable;
import 'adapty_period_unit.dart';
import 'private/json_builder.dart';

part 'private/adapty_subscription_period_json_builder.dart';

@immutable
class AdaptySubscriptionPeriod {
  /// The unit of time that a subscription period is specified in.
  /// The possible values are: day, week, month, year.
  final AdaptyPeriodUnit unit;

  /// The number of period units.
  final int numberOfUnits;

  const AdaptySubscriptionPeriod._(
    this.unit,
    this.numberOfUnits,
  );

  @override
  String toString() => '(unit: $unit, numberOfUnits: $numberOfUnits)';
}
