part of 'onboard.dart';

class OnboardActor with Logging, Actor {
  late final _stage = Core.get<StageStore>();
  late final _onboardingStep = Core.get<OnboardingStepValue>();
  late final _payment = Core.get<PaymentActor>();

  @override
  onStart(Marker m) async {
    final step = await _onboardingStep.fetch(m);
    if (step != "first") {
      await _onboardingStep.change(m, "first");
      _payment.reportOnboarding(OnboardingStep.onboardScreenReached);
      await _stage.showModal(StageModal.onboarding, m);
    }
  }
}