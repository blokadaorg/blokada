part of 'onboard.dart';

class OnboardActor with Logging, Actor {
  late final _stage = Core.get<StageStore>();
  late final _onboardIntro = Core.get<OnboardIntroValue>();
  late final _onboardSafari = Core.get<OnboardSafariValue>();

  late final _payment = Core.get<PaymentActor>();
  late final _rateMetadata = RateMetadataValue();

  @override
  onStart(Marker m) async {
    final step = await _onboardIntro.fetch(m);
    await _onboardSafari.fetch(m);

    if (step == null) {
      log(m).t("Onboarding not done before, checking metadata");
      _onboardIntro.change(m, "seenNotActed");
      final meta = await _rateMetadata.fetch(m);
      if (meta != null) {
        log(m).t("Metadata present, skipping onboard screen");
        // Assume that user has rate meta in local storage, it means that the user
        // has been using the app before (older version that introduced onboarding)
        // Then, just skip the onboard screen
        await _onboardIntro.change(m, "first");
        return;
      }
    }

    if (step != "first") {
      _payment.reportOnboarding(OnboardingStep.onboardScreenReached);
      await _stage.showModal(StageModal.onboarding, m);
    }
  }

  markIntroSeen(Marker m) async {
    await _onboardIntro.change(m, "first");
  }

  markSafariSeen(Marker m) async {
    await _onboardSafari.change(m, true);
  }
}
