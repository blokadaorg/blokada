part of 'payment.dart';

class PaymentActor with Actor, Logging implements AdaptyUIObserver {
  late final _accountId = Core.get<api.AccountId>();
  late final _account = Core.get<AccountStore>();
  late final _api = Core.get<PaymentApi>();
  late final _family = Core.get<FamilyActor>();
  late final _onboard = Core.get<CurrentOnboardingStepValue>();
  late final _stage = Core.get<StageStore>();

  late final _adapty = Adapty();
  late final _adaptyUi = AdaptyUI();

  @override
  onStart(Marker m) async {
    await _onboard.fetch(m);

    _adaptyUi.setObserver(this);
    await _adapty.activate(
      configuration: AdaptyConfiguration(
          apiKey: "public_live_6b1uSAaQ.EVLlSnbFDIarK82Qkqiv")
        ..withLogLevel(
            Core.act.isRelease ? AdaptyLogLevel.warn : AdaptyLogLevel.debug)
        ..withObserverMode(false)
        ..withIpAddressCollectionDisabled(true)
        ..withIdfaCollectionDisabled(true),
    );

    // Set Adapty fallback for any connection problems situations
    try {
      final assetId = Core.act.platform == PlatformType.iOS ? "ios" : "android";
      await _adapty.setFallbackPaywalls("assets/fallbacks/$assetId.json");
    } catch (e, s) {
      log(m)
          .e(msg: "Adapty: Failed setting fallback, ignore", err: e, stack: s);
    }

    _accountId.onChangeInstant((it) {
      log(it.m).i("Adapty: Identifying account ID");
      _adapty.identify(it.now);

      if (!_account.type.isActive()) {
        // Inactive account: changed manually, or new load
        reportOnboarding(OnboardingStep.appStarting, reset: true);
      }
    });

    // TODO: change to new Value type
    _account.addOn(accountChanged, _onAccountChanged);
  }

  _onAccountChanged(Marker m) async {
    if (_account.type.isActive()) {
      reportOnboarding(OnboardingStep.accountActivated);
    }
  }

  reportOnboarding(OnboardingStep step, {bool reset = false}) async {
    final current = await _onboard.now();
    if (current == null || current.order < step.order || reset) {
      // Next step reached, report it
      await log(Markers.ui).trace("reportOnboarding", (m) async {
        await _adapty.logShowOnboarding(
          name: "primaryOnboard",
          screenName: step.name,
          screenOrder: step.order,
        );
        await _onboard.change(m, step);
      });
    }
  }

  showPaywall(Marker m) async {
    await reportOnboarding(OnboardingStep.ctaTapped);
    try {
      final view = await _createAdaptyPaywall();
      await view.present();
    } catch (e, s) {
      await _handleFailure(m, "Failed creating paywall", e,
          s: s, temporary: true);
    }
  }

  Future<AdaptyUIView> _createAdaptyPaywall() async {
    final paywall = await _adapty.getPaywall(
      placementId: "primary",
      locale: I18n.localeStr,
    );

    return await _adaptyUi.createPaywallView(
      paywall: paywall,
      // customTimers: {
      //   'CUSTOM_TIMER_6H':
      //       DateTime.now().add(const Duration(seconds: 3600 * 6)),
      //   'CUSTOM_TIMER_NY': DateTime(2025, 1, 1), // New Year 2025
      // },
      preloadProducts: false,
    );
  }

  _checkoutSuccessfulPayment(AdaptyProfile profile,
      {bool restore = false}) async {
    await log(Markers.ui).trace("checkoutSuccessfulPayment", (m) async {
      final account = await _api.postCheckout(m, profile.profileId);

      try {
        final type = AccountType.values.byName(account.type ?? "unknown");
        if (!type.isActive()) throw Exception("Account inactive after restore");

        log(m).log(
          msg: "purchased/restored active account",
          attr: {"accountId": account.id},
          sensitive: true,
        );

        await _account.propose(account, m);
        await _family.activateCta(m);
      } catch (e, s) {
        await _handleFailure(m, "Failed checkout", e, s: s, restore: restore);
      }
    });
  }

  _handleFailure(Marker m, String msg, Object e,
      {StackTrace? s, bool restore = false, bool temporary = false}) async {
    log(m).e(msg: "Adapty: $msg", err: e, stack: s);

    var sheet = StageModal.paymentFailed;
    if (restore) {
      sheet = StageModal.accountRestoreFailed;
    } else if (temporary) {
      sheet = StageModal.paymentTempUnavailable;
    }

    await _stage.showModal(sheet, m);
  }

  @override
  void paywallViewDidFinishPurchase(AdaptyUIView view,
      AdaptyPaywallProduct product, AdaptyPurchaseResult purchaseResult) {
    view.dismiss();

    switch (purchaseResult) {
      case AdaptyPurchaseResultSuccess(profile: final profile):
        // successful purchase
        _checkoutSuccessfulPayment(profile);
        break;
      case AdaptyPurchaseResultPending():
        // purchase is pending
        log(Markers.ui).t("Adapty: purchase result pending");
        break;
      case AdaptyPurchaseResultUserCancelled():
        // user cancelled the purchase
        log(Markers.ui).t("Adapty: user canceled");
        break;
    }
  }

  @override
  void paywallViewDidFinishRestore(AdaptyUIView view, AdaptyProfile profile) {
    view.dismiss();
    _checkoutSuccessfulPayment(profile, restore: true);
  }

  @override
  void paywallViewDidPerformAction(AdaptyUIView view, AdaptyUIAction action) {
    switch (action) {
      case const CloseAction():
      case const AndroidSystemBackAction():
        view.dismiss();
        break;
      case OpenUrlAction(url: final url):
        _stage.openUrl(url, Markers.ui);
        break;
      default:
        break;
    }
  }

  @override
  void paywallViewDidFailLoadingProducts(AdaptyUIView view, AdaptyError error) {
    view.dismiss();
    _handleFailure(Markers.ui, "Failed loading products", error,
        temporary: true);
  }

  @override
  void paywallViewDidFailPurchase(
      AdaptyUIView view, AdaptyPaywallProduct product, AdaptyError error) {
    view.dismiss();
    _handleFailure(Markers.ui, "Failed purchase", error);
  }

  @override
  void paywallViewDidFailRendering(AdaptyUIView view, AdaptyError error) {
    view.dismiss();
    _handleFailure(Markers.ui, "Failed rendering", error, temporary: true);
  }

  @override
  void paywallViewDidFailRestore(AdaptyUIView view, AdaptyError error) {
    view.dismiss();
    _handleFailure(Markers.ui, "Failed restore", error, restore: true);
  }

  @override
  void paywallViewDidSelectProduct(AdaptyUIView view, String productId) {}

  @override
  void paywallViewDidStartPurchase(
      AdaptyUIView view, AdaptyPaywallProduct product) {}

  @override
  void paywallViewDidStartRestore(AdaptyUIView view) {}
}
