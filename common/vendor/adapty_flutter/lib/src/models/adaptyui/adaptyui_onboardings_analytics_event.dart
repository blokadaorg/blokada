// ignore_for_file: deprecated_member_use_from_same_package
part '../private/adaptyui_onboardings_analytics_event_json_builder.dart';

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
sealed class AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEvent();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsAnalyticsEventOnboardingStarted extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventOnboardingStarted();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsAnalyticsEventScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventScreenPresented();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsAnalyticsEventScreenCompleted extends AdaptyOnboardingsAnalyticsEvent {
  final String? elementId;
  final String? reply;

  const AdaptyOnboardingsAnalyticsEventScreenCompleted({
    this.elementId,
    this.reply,
  });
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsAnalyticsEventSecondScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventSecondScreenPresented();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsAnalyticsEventRegistrationScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventRegistrationScreenPresented();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsAnalyticsEventProductsScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventProductsScreenPresented();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsAnalyticsEventUserEmailCollected extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventUserEmailCollected();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsAnalyticsEventOnboardingCompleted extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventOnboardingCompleted();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsAnalyticsEventUnknown extends AdaptyOnboardingsAnalyticsEvent {
  final String name;

  const AdaptyOnboardingsAnalyticsEventUnknown({
    required this.name,
  });
}
