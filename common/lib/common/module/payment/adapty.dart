part of 'payment.dart';

// Currently we have two Adapty SDK integrations, hence the interface.
// We are waiting for the flutter SDK to add support for android prorate modes.
// After that, we can drop the android SDK.
// This is handled through flutter platform channel (the other class).
class AdaptyPaymentChannel
    with Logging, PaymentChannel
    implements AdaptyUIObserver {
  late final _stage = Core.get<StageStore>();
  late final _actor = Core.get<PaymentActor>(); // Circular dep

  late final _adapty = Adapty();
  late final _adaptyUi = AdaptyUI();

  AdaptyUIView? _paymentView;
  String? _paymentViewForPlacementId;

  @override
  init(Marker m, String apiKey, String? accountId, bool verboseLogs) async {
    _adaptyUi.setObserver(this);

    await _adapty.activate(
      configuration: AdaptyConfiguration(apiKey: apiKey)
        ..withCustomerUserId(accountId)
        ..withLogLevel(verboseLogs ? AdaptyLogLevel.debug : AdaptyLogLevel.warn)
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
  }

  @override
  identify(String accountId) async {
    await _adapty.identify(accountId);
  }

  @override
  logOnboardingStep(String name, OnboardingStep step) async {
    await _adapty.logShowOnboarding(
        name: name, screenName: step.name, screenOrder: step.order);
  }

  @override
  preload(Marker m, Placement placement) async {
    _paymentView = await _createPaywall(m, placement);
    _paymentViewForPlacementId = placement.id;
  }

  @override
  showPaymentScreen(Marker m, Placement placement,
      {bool forceReload = false}) async {
    if (forceReload ||
        _paymentViewForPlacementId != placement.id ||
        _paymentView == null) {
      _paymentView = await _createPaywall(m, placement);
      _paymentViewForPlacementId = placement.id;
    }

    await _paymentView!.present();
  }

  @override
  closePaymentScreen({AdaptyUIView? view}) async {
    view?.dismiss();
    if (view == null) _paymentView?.dismiss();
    _paymentView = null;
    _actor.handleScreenClosed();
  }

  Future<AdaptyUIView> _createPaywall(Marker m, Placement placement) async {
    final paywall = await _fetchPaywall(m, placement);
    return await _adaptyUi.createPaywallView(
      paywall: paywall,
      preloadProducts: false,
    );
  }

  Future<AdaptyPaywall> _fetchPaywall(Marker m, Placement placement) async {
    return await log(m).trace("fetchPaywall", (m) async {
      final paywall = await _adapty.getPaywall(
        placementId: placement.id,
        locale: I18n.localeStr,
      );
      return paywall;
    });
  }

  @override
  void paywallViewDidFinishPurchase(AdaptyUIView view,
      AdaptyPaywallProduct product, AdaptyPurchaseResult purchaseResult) {
    switch (purchaseResult) {
      case AdaptyPurchaseResultSuccess(profile: final profile):
        // successful purchase
        closePaymentScreen(view: view);
        _actor.checkoutSuccessfulPayment(profile.profileId);
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
    _actor.checkoutSuccessfulPayment(profile.profileId, restore: true);
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
    _actor.handleFailure(Markers.ui, "Failed loading products", error,
        temporary: true);
  }

  @override
  void paywallViewDidFailPurchase(
      AdaptyUIView view, AdaptyPaywallProduct product, AdaptyError error) {
    closePaymentScreen(view: view);
    _actor.handleFailure(Markers.ui, "Failed purchase", error);
  }

  @override
  void paywallViewDidFailRendering(AdaptyUIView view, AdaptyError error) {
    //closePaymentScreen(view: view);
    //_handleFailure(Markers.ui, "Failed rendering", error, temporary: true);
    log(Markers.ui).e(msg: "Failed rendering adapty", err: error);
  }

  @override
  void paywallViewDidFailRestore(AdaptyUIView view, AdaptyError error) {
    closePaymentScreen(view: view);
    _actor.handleFailure(Markers.ui, "Failed restore", error, restore: true);
  }

  @override
  void paywallViewDidSelectProduct(AdaptyUIView view, String productId) {}

  @override
  void paywallViewDidStartPurchase(
      AdaptyUIView view, AdaptyPaywallProduct product) {}

  @override
  void paywallViewDidStartRestore(AdaptyUIView view) {}
}
