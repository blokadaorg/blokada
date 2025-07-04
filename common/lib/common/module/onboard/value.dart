part of 'onboard.dart';

// This holds the first onboarding screen (welcome screen) seen state
class OnboardIntroValue extends StringPersistedValue {
  OnboardIntroValue() : super("onboarding:step", sensitive: false);
}

// This holds the Safari Youtube extension onboarding state (if seen)
class OnboardSafariValue extends BoolPersistedValue {
  OnboardSafariValue() : super("onboarding:safari");
}
