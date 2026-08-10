// ignore_for_file: deprecated_member_use_from_same_package
part of '../adaptyui/adaptyui_onboardings_analytics_event.dart';

extension AdaptyOnboardingsAnalyticsEventJSONBuilder on AdaptyOnboardingsAnalyticsEvent {
  static AdaptyOnboardingsAnalyticsEvent fromJsonValue(Map<String, dynamic> json) {
    final name = json[_Keys.name];

    switch (name) {
      case _Keys.onboardingStarted:
        return AdaptyOnboardingsAnalyticsEventOnboardingStarted();
      case _Keys.screenPresented:
        return AdaptyOnboardingsAnalyticsEventScreenPresented();
      case _Keys.screenCompleted:
        return AdaptyOnboardingsAnalyticsEventScreenCompleted(
          elementId: json[_Keys.elementId],
          reply: json[_Keys.reply],
        );
      case _Keys.secondScreenPresented:
        return AdaptyOnboardingsAnalyticsEventSecondScreenPresented();
      case _Keys.registrationScreenPresented:
        return AdaptyOnboardingsAnalyticsEventRegistrationScreenPresented();
      case _Keys.productsScreenPresented:
        return AdaptyOnboardingsAnalyticsEventProductsScreenPresented();
      case _Keys.userEmailCollected:
        return AdaptyOnboardingsAnalyticsEventUserEmailCollected();
      case _Keys.onboardingCompleted:
        return AdaptyOnboardingsAnalyticsEventOnboardingCompleted();
      default:
        return AdaptyOnboardingsAnalyticsEventUnknown(
          name: name,
        );
    }
  }
}

class _Keys {
  static const name = 'name';

  static const elementId = 'element_id';
  static const reply = 'reply';

  static const onboardingStarted = 'onboarding_started';
  static const screenPresented = 'screen_presented';
  static const screenCompleted = 'screen_completed';
  static const secondScreenPresented = 'second_screen_presented';
  static const registrationScreenPresented = 'registration_screen_presented';
  static const productsScreenPresented = 'products_screen_presented';
  static const userEmailCollected = 'user_email_collected';
  static const onboardingCompleted = 'onboarding_completed';
}
