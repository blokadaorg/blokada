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

  bool _adaptyInitialized = false;
  AdaptyUIView? _adaptyUiView;

  Function onPaymentScreenOpened = () => {};

  @override
  onStart(Marker m) async {
    await _onboard.fetch(m);

    /// The Adapty init handling is convoluted because of how they handle profiles.
    /// We do not want to create unnecessary profiles.
    ///
    /// Init flow:
    /// - if existing account id from cloud storage has ever been active, use it
    /// - if account was never active (ie. new user), init without any account ID
    ///
    /// After init:
    /// - pass account id to Adapty if it changes, and has been active before
    _accountId.onChangeInstant((it) async {
      if (_account.account?.hasBeenActiveBefore() ?? false) {
        if (!_adaptyInitialized) {
          // Initialise Adapty with account ID, if account has been active before
          log(it.m).log(msg: "Adapty: initialising",
              attr: {"accountId": it.now}, sensitive: true);
          _adaptyInitialized = true;
          await _initAdapty(it.m, it.now);
        } else {
          // Pass account ID to Adapty on change, whenever active
          log(it.m).log(msg: "Adapty: identifying",
              attr: {"accountId": it.now}, sensitive: true);
          await _adapty.identify(it.now);
        }
      } else {
        if (!_adaptyInitialized) {
          // Initialise Adapty with no account ID provided (never active)
          log(it.m).log(msg: "Adapty: initialising without accountId");
          _adaptyInitialized = true;
          await _initAdapty(it.m, null);
        } else {
          // Inactive account: changed manually, or new load
          await reportOnboarding(OnboardingStep.appStarting, reset: true);
        }
      }
    });

    // TODO: change to new Value type
    _account.addOn(accountChanged, _onAccountChanged);
  }

  _initAdapty(Marker m, String? accountId) async {
    _adaptyUi.setObserver(this);

    // TODO: move to assets or somewhere
    var apiKey = "public_live_jIrWAAbd.q43qsMhj7rTLOpF3zGBd";
    if (Core.act.isFamily) {
      apiKey = "public_live_6b1uSAaQ.EVLlSnbFDIarK82Qkqiv";
    }

    await _adapty.activate(
      configuration: AdaptyConfiguration(apiKey: apiKey)
        ..withCustomerUserId(accountId)
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

  openPaymentScreen(Marker m) async {
    return await log(m).trace("openPaymentScreen", (m) async {
      await reportOnboarding(OnboardingStep.ctaTapped);
      try {
        final view = await _createAdaptyPaywall();
        await view.present();
        _adaptyUiView = view;
        onPaymentScreenOpened();
      } catch (e, s) {
        await _handleFailure(m, "Failed creating paywall", e,
            s: s, temporary: true);
      }
    });
  }

  closePaymentScreen({AdaptyUIView? view}) {
    view?.dismiss();
    if (view == null) _adaptyUiView?.dismiss();
    _adaptyUiView = null;
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
      try {
        final account = await _api.postCheckout(m, profile.profileId);

        final type = AccountType.values.byName(account.type ?? "unknown");
        await _account.propose(account, m);
        if (!type.isActive()) throw Exception("Account inactive after restore");

        log(m).log(
          msg: "purchased/restored active account",
          attr: {"accountId": account.id},
          sensitive: true,
        );

        // TODO: make it for both not only family
        if (Core.act.isFamily) {
          await _family.activateCta(m);
        }
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

    await sleepAsync(const Duration(seconds: 1));
    await _stage.showModal(sheet, m);
  }

  @override
  void paywallViewDidFinishPurchase(AdaptyUIView view,
      AdaptyPaywallProduct product, AdaptyPurchaseResult purchaseResult) {
    closePaymentScreen(view: view);

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
    closePaymentScreen(view: view);
    _checkoutSuccessfulPayment(profile, restore: true);
  }

  @override
  void paywallViewDidPerformAction(AdaptyUIView view, AdaptyUIAction action) {
    switch (action) {
      case const CloseAction():
      case const AndroidSystemBackAction():
        closePaymentScreen(view: view);
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
    closePaymentScreen(view: view);
    _handleFailure(Markers.ui, "Failed loading products", error,
        temporary: true);
  }

  @override
  void paywallViewDidFailPurchase(
      AdaptyUIView view, AdaptyPaywallProduct product, AdaptyError error) {
    closePaymentScreen(view: view);
    _handleFailure(Markers.ui, "Failed purchase", error);
  }

  @override
  void paywallViewDidFailRendering(AdaptyUIView view, AdaptyError error) {
    closePaymentScreen(view: view);
    _handleFailure(Markers.ui, "Failed rendering", error, temporary: true);
  }

  @override
  void paywallViewDidFailRestore(AdaptyUIView view, AdaptyError error) {
    closePaymentScreen(view: view);
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
