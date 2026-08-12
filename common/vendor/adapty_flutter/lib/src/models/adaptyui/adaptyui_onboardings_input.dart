// ignore_for_file: deprecated_member_use_from_same_package

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
sealed class AdaptyOnboardingsInput {
  const AdaptyOnboardingsInput();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsTextInput extends AdaptyOnboardingsInput {
  final String value;

  const AdaptyOnboardingsTextInput({
    required this.value,
  });
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsEmailInput extends AdaptyOnboardingsInput {
  final String value;

  const AdaptyOnboardingsEmailInput({
    required this.value,
  });
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsNumberInput extends AdaptyOnboardingsInput {
  final double value;

  const AdaptyOnboardingsNumberInput({
    required this.value,
  });
}
