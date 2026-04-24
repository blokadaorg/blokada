part of 'payment.dart';

// Currently we have two Adapty SDK integrations, hence the interface.
// We are waiting for the flutter SDK to add support for android prorate modes.
// After that, we can drop the android SDK.
// This is handled through flutter platform channel (the other class).
class AdaptyPaymentChannel with Logging, PaymentChannel implements AdaptyUIPaywallsEventsObserver {
  late final _stage = Core.get<StageStore>();
  late final _actor = Core.get<PaymentActor>(); // Circular dep
  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  late final _adapty = Adapty();

  AdaptyPaywall? _paymentPaywall;
  String? _paymentPaywallForPlacementId;
  bool _isEmbeddedPaywallVisible = false;
  bool _isClosingEmbeddedPaywall = false;

  @override
  init(Marker m, String apiKey, String? accountId, bool verboseLogs) async {
    final configuration = AdaptyConfiguration(apiKey: apiKey)
      ..withLogLevel(verboseLogs ? AdaptyLogLevel.debug : AdaptyLogLevel.warn)
      ..withObserverMode(false)
      ..withIpAddressCollectionDisabled(true)
      ..withGoogleAdvertisingIdCollectionDisabled(true)
      ..withAppleIdfaCollectionDisabled(true);

    if (accountId != null) {
      configuration.withCustomerUserId(accountId);
    }

    await _adapty.activate(configuration: configuration);

    // Set Adapty fallback for any connection problems situations
    try {
      final assetId = Core.act.platform == PlatformType.iOS ? "ios" : "android";
      await _adapty.setFallbackPaywalls("assets/fallbacks/$assetId.json");
    } catch (e, s) {
      log(m).e(msg: "Adapty: Failed setting fallback, ignore", err: e, stack: s);
    }
  }

  @override
  identify(String accountId) async {
    await _adapty.identify(accountId);
  }

  @override
  logOnboardingStep(String name, OnboardingStep step) async {
    // adapty_flutter 3.15.x no longer exposes the previous onboarding logging
    // helper. Keep this as a best-effort no-op until we decide whether to
    // replace it with a native-only path or a different Adapty API.
  }

  @override
  preload(Marker m, Placement placement) async {
    _paymentPaywall = await _fetchPaywall(m, placement);
    _paymentPaywallForPlacementId = placement.id;
  }

  @override
  showPaymentScreen(Marker m, Placement placement, {bool forceReload = false}) async {
    if (forceReload || _paymentPaywallForPlacementId != placement.id || _paymentPaywall == null) {
      _paymentPaywall = await _fetchPaywall(m, placement);
      _paymentPaywallForPlacementId = placement.id;
    }

    _isClosingEmbeddedPaywall = false;
    _isEmbeddedPaywallVisible = true;
    await _modalWidget.change(m, (context) => AdaptyEmbeddedPaywallSheet(
          channel: this,
          paywall: _paymentPaywall!,
        ));
    await _modal.change(m, Modal.adaptyPaywall);
  }

  @override
  closePaymentScreen(bool isError, {AdaptyUIPaywallView? view}) async {
    final wasEmbeddedPaywallVisible = _isEmbeddedPaywallVisible;
    _isClosingEmbeddedPaywall = true;
    _isEmbeddedPaywallVisible = false;

    if (!wasEmbeddedPaywallVisible) {
      await view?.dismiss();
    }

    await _modal.change(Markers.ui, null);
    _isClosingEmbeddedPaywall = false;
    await _actor.handleScreenClosed(Markers.ui, isError: isError);
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

  void handleEmbeddedPaywallDisposed() {
    if (!_isEmbeddedPaywallVisible || _isClosingEmbeddedPaywall) return;
    unawaited(closePaymentScreen(false));
  }

  @override
  void paywallViewDidFinishPurchase(
      AdaptyUIPaywallView view, AdaptyPaywallProduct product, AdaptyPurchaseResult purchaseResult) {
    switch (purchaseResult) {
      case AdaptyPurchaseResultSuccess(profile: final profile):
        // successful purchase
        closePaymentScreen(false, view: view);
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
  void paywallViewDidFinishRestore(AdaptyUIPaywallView view, AdaptyProfile profile) {
    closePaymentScreen(false, view: view);
    _actor.checkoutSuccessfulPayment(profile.profileId, restore: true);
  }

  @override
  void paywallViewDidPerformAction(AdaptyUIPaywallView view, AdaptyUIAction action) {
    switch (action) {
      case const CloseAction():
      case const AndroidSystemBackAction():
        closePaymentScreen(false, view: view);
        break;
      case OpenUrlAction(url: final url):
        _stage.openUrl(url, Markers.ui);
        break;
      default:
        break;
    }
  }

  @override
  void paywallViewDidFailLoadingProducts(AdaptyUIPaywallView view, AdaptyError error) {
    closePaymentScreen(true, view: view);
    _actor.handleFailure(Markers.ui, "Failed loading products", error, temporary: true);
  }

  @override
  void paywallViewDidFailPurchase(
      AdaptyUIPaywallView view, AdaptyPaywallProduct product, AdaptyError error) {
    closePaymentScreen(true, view: view);
    _actor.handleFailure(Markers.ui, "Failed purchase", error);
  }

  @override
  void paywallViewDidFailRendering(AdaptyUIPaywallView view, AdaptyError error) {
    //closePaymentScreen(view: view);
    //_handleFailure(Markers.ui, "Failed rendering", error, temporary: true);
    log(Markers.ui).e(msg: "Failed rendering adapty", err: error);
  }

  @override
  void paywallViewDidFailRestore(AdaptyUIPaywallView view, AdaptyError error) {
    closePaymentScreen(true, view: view);
    _actor.handleFailure(Markers.ui, "Failed restore", error, restore: true);
  }

  @override
  void paywallViewDidSelectProduct(AdaptyUIPaywallView view, String productId) {}

  @override
  void paywallViewDidStartPurchase(AdaptyUIPaywallView view, AdaptyPaywallProduct product) {}

  @override
  void paywallViewDidStartRestore(AdaptyUIPaywallView view) {}

  @override
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {}

  @override
  void paywallViewDidAppear(AdaptyUIPaywallView view) {}

  @override
  void paywallViewDidDisappear(AdaptyUIPaywallView view) {}

  @override
  Future<void> setCustomAttributes(Marker m, Map<String, dynamic> attributes) async {
    return await log(m).trace("setCustomAttributes", (m) async {
      // Extract pre-processed custom attributes from Flutter
      final customAttributes = attributes['custom_attributes'] as List<Map<String, dynamic>>?;

      if (customAttributes == null || customAttributes.isEmpty) {
        log(m).t("No valid custom attributes to sync to Adapty");
        return;
      }

      try {
        // Create builder and add custom attributes
        final builder = AdaptyProfileParametersBuilder();

        for (final attr in customAttributes) {
          final key = attr['key'] as String;
          final value = attr['value'];

          // Use appropriate method based on value type
          if (value is String) {
            builder.setCustomStringAttribute(value, key);
          } else if (value is double) {
            builder.setCustomDoubleAttribute(value, key);
          } else if (value is num) {
            builder.setCustomDoubleAttribute(value.toDouble(), key);
          } else {
            // Convert other types to string
            builder.setCustomStringAttribute(value.toString(), key);
          }
        }

        await _adapty.updateProfile(builder.build());
        log(m).i("Synced ${customAttributes.length} custom attributes to Adapty");
      } on AdaptyError catch (adaptyError) {
        throw Exception("Adapty error: ${adaptyError.message}");
      }
    });
  }
}
