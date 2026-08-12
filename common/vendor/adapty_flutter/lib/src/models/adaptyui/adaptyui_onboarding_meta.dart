// ignore_for_file: deprecated_member_use_from_same_package
import 'package:meta/meta.dart' show immutable;

import '../private/json_builder.dart';

part '../private/adaptyui_onboarding_meta_json_builder.dart';

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
@immutable
class AdaptyUIOnboardingMeta {
  final String onboardingId;
  final String screenClientId;
  final int screenIndex;
  final int screensTotal;

  const AdaptyUIOnboardingMeta({
    required this.onboardingId,
    required this.screenClientId,
    required this.screenIndex,
    required this.screensTotal,
  });

  @override
  String toString() {
    return 'AdaptyUIOnboardingMeta(onboardingId: $onboardingId, screenClientId: $screenClientId, screenIndex: $screenIndex, screensTotal: $screensTotal)';
  }
}
