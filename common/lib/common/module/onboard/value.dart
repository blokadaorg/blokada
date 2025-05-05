part of 'onboard.dart';

class OnboardIntroValue extends StringPersistedValue {
  OnboardIntroValue() : super("onboarding:step", sensitive: false);
}

class OnboardSafariValue extends BoolPersistedValue {
  OnboardSafariValue() : super("onboarding:safari");
}
