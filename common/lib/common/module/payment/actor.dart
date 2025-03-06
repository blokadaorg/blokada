part of 'payment.dart';

enum Placement {
  primary("primary"),
  plusUpgrade("home_plus_upgrade");

  final String id;

  const Placement(this.id);
}

class PaymentActor with Actor, Logging implements AdaptyUIObserver {
  late final _accountEphemeral = Core.get<api.AccountEphemeral>();
  late final _account = Core.get<AccountStore>();
  late final _api = Core.get<PaymentApi>();
  late final _family = Core.get<FamilyActor>();
  late final _onboard = Core.get<CurrentOnboardingStepValue>();
  late final _stage = Core.get<StageStore>();

  late final _adapty = Adapty();
  late final _adaptyUi = AdaptyUI();

  bool _adaptyInitialized = false;
  AdaptyUIView? _paymentView;

  Map<Placement, _Prefetch> _prefetch = {};

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
    _accountEphemeral.onChangeInstant((it) async {
      if (it.now.hasBeenActiveBefore()) {
        if (!_adaptyInitialized) {
          // Initialise Adapty with account ID, if account has been active before
          log(it.m).log(
            msg: "Adapty: initialising",
            attr: {"accountId": it.now.id},
            sensitive: true,
          );
          _adaptyInitialized = true;
          await _initAdapty(it.m, it.now.id);
        } else {
          // Pass account ID to Adapty on change, whenever active
          log(it.m).log(
            msg: "Adapty: identifying",
            attr: {"accountId": it.now.id},
            sensitive: true,
          );
          await _adapty.identify(it.now.id);
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
        ..withGoogleAdvertisingIdCollectionDisabled(true)
        ..withAppleIdfaCollectionDisabled(true),
    );

    // Set Adapty fallback for any connection problems situations
    try {
      final assetPlatform =
          Core.act.platform == PlatformType.iOS ? "ios" : "android";
      final assetFlavor = Core.act.isFamily ? "family" : "six";
      final assetId = "$assetFlavor-$assetPlatform";
      await _adapty.setFallbackPaywalls("assets/fallbacks/$assetId.json");
    } catch (e, s) {
      log(m)
          .e(msg: "Adapty: Failed setting fallback, ignore", err: e, stack: s);
    }

    // Paywall prefetch
    await _fetchPaywall(m, Placement.primary);
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

  openPaymentScreen(Marker m, {Placement placement = Placement.primary}) async {
    return await log(m).trace("openPaymentScreen", (m) async {
      await reportOnboarding(OnboardingStep.ctaTapped);
      try {
        final view = await _createAdaptyPaywall(placement);
        await view.present();
        _paymentView = view;
        onPaymentScreenOpened();
      } catch (e, s) {
        await _handleFailure(m, "Failed creating paywall", e,
            s: s, temporary: true);
      }
    });
  }

  closePaymentScreen({AdaptyUIView? view}) {
    view?.dismiss();
    if (view == null) _paymentView?.dismiss();
    _paymentView = null;
  }

  Future<AdaptyUIView> _createAdaptyPaywall(Placement placement) async {
    final paywall = await _fetchPaywall(Markers.ui, placement);
    return await _adaptyUi.createPaywallView(
      paywall: paywall,
      preloadProducts: false,
    );
  }

  Future<AdaptyPaywall> _fetchPaywall(Marker m, Placement placement) async {
    final paywall = _prefetch[placement];
    if (paywall == null || paywall.isExpired()) {
      return await log(m).trace("fetchPaywall", (m) async {
        final paywall = await _adapty.getPaywall(
          placementId: placement.id,
          locale: I18n.localeStr,
        );
        _prefetch[placement] = _Prefetch(paywall);
        return paywall;
      });
    } else {
      return paywall.paywall!;
    }
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
    switch (purchaseResult) {
      case AdaptyPurchaseResultSuccess(profile: final profile):
        // successful purchase
        closePaymentScreen(view: view);
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

class _Prefetch {
  final DateTime _fetchedAt = DateTime.now();
  final AdaptyPaywall? paywall;

  _Prefetch(this.paywall);

  bool isExpired() {
    return DateTime.now().difference(_fetchedAt) > const Duration(minutes: 3);
  }
}
