//
//  adapty_onboarding_screen_parameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

// ignore_for_file: deprecated_member_use_from_same_package
import 'package:meta/meta.dart' show immutable;
part 'private/adapty_onboarding_screen_parameters_json_builder.dart';

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
@immutable
class AdaptyOnboardingScreenParameters {
  /// [Nullable]
  final String? name;

  /// [Nullable]
  final String? screenName;
  final int screenOrder;

  const AdaptyOnboardingScreenParameters({
    String? name,
    String? screenName,
    required int screenOrder,
  })  : this.name = name,
        this.screenName = screenName,
        this.screenOrder = screenOrder;

  @override
  String toString() => '(name: $name, screenName: $screenName, screenOrder: $screenOrder)';
}
