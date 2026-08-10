part of 'payment.dart';

// Currently we have two Adapty SDK integrations, hence the interface.
// We are waiting for the flutter SDK to add support for android prorate modes.
// After that, we can drop the android SDK.
// This is handled through flutter platform channel (the other class).
class AdaptyPaymentChannel with Logging, PaymentChannel implements AdaptyUIFlowsEventsObserver {
  late final _stage = Core.get<StageStore>();
  late final _actor = Core.get<PaymentActor>(); // Circular dep

  late final _adapty = Adapty();
  late final _adaptyUi = AdaptyUI();

  AdaptyUIFlowView? _paymentView;
  String? _paymentViewForPlacementId;

  @override
  init(Marker m, String apiKey, String? accountId, bool verboseLogs) async {
    _adaptyUi.setFlowsEventsObserver(this);

    // Adapty 3.17 made withCustomerUserId require a non-null String. accountId
    // can be null at activation (anonymous start); only bind it when present,
    // which matches the old nullable behaviour. When an account id exists it is
    // also bound separately via identify(), so attribution is unaffected.
    final configuration = AdaptyConfiguration(apiKey: apiKey)
      ..withLogLevel(verboseLogs ? AdaptyLogLevel.debug : AdaptyLogLevel.warn)
      ..withObserverMode(false)
      ..withIpAddressCollectionDisabled(true)
      ..withGoogleAdvertisingIdCollectionDisabled(true)
      ..withAppleIdfaCollectionDisabled(true);
    if (accountId != null) configuration.withCustomerUserId(accountId);

    await _adapty.activate(configuration: configuration);

    // Set Adapty fallback for any connection problems situations
    try {
      final assetId = Core.act.platform == PlatformType.iOS ? "ios" : "android";
      await _adapty.setFallback("assets/fallbacks/$assetId.json");
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
    // Adapty 3.17 removed Adapty.logShowOnboarding (the manual onboarding-step
    // analytics API) in favour of its hosted AdaptyUI onboarding views, which
    // we don't use — onboarding is rendered by the app. There is no drop-in
    // replacement for logging a custom step. The native Android path already
    // no-op'd this on Adapty Android 3.15.x, so the Adapty-side onboarding
    // analytics is gone app-wide; local step tracking in
    // PaymentActor.reportOnboarding is unaffected.
    log(Markers.ui)
        .t("Adapty: skipping onboarding step '$name/${step.name}' (logShowOnboarding removed in 3.17)");
  }

  @override
  preload(Marker m, Placement placement) async {
    _paymentView = await _createPaywall(m, placement);
    _paymentViewForPlacementId = placement.id;
  }

  @override
  showPaymentScreen(Marker m, Placement placement, {bool forceReload = false}) async {
    if (forceReload || _paymentViewForPlacementId != placement.id || _paymentView == null) {
      _paymentView = await _createPaywall(m, placement);
      _paymentViewForPlacementId = placement.id;
    }

    try {
      await _paymentView!.present();
    } catch (_) {
      // AdaptyUIFlowView is single-use; drop the spent view so the next
      // open recreates it instead of re-presenting a view that already failed.
      _paymentView = null;
      _paymentViewForPlacementId = null;
      rethrow;
    }
  }

  @override
  closePaymentScreen(bool isError, {AdaptyUIFlowView? view}) async {
    await view?.dismiss();
    if (view == null) await _paymentView?.dismiss();
    _paymentView = null;
    _paymentViewForPlacementId = null;
    await _actor.handleScreenClosed(Markers.ui, isError: isError);
  }

  Future<AdaptyUIFlowView> _createPaywall(Marker m, Placement placement) async {
    final flow = await _fetchFlow(m, placement);
    // Since 4.0 a flow is localized when its view is built; without an explicit
    // locale it renders in `en` regardless of device language.
    return await _adaptyUi.createFlowView(
      flow: flow,
      locale: I18n.localeStr,
      preloadProducts: false,
    );
  }

  Future<AdaptyFlow> _fetchFlow(Marker m, Placement placement) async {
    return await log(m).trace("fetchFlow", (m) async {
      final flow = await _adapty.getFlow(placementId: placement.id);
      return flow;
    });
  }

  @override
  void flowViewDidFinishPurchase(
      AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult purchaseResult) {
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
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {
    closePaymentScreen(false, view: view);
    _actor.checkoutSuccessfulPayment(profile.profileId, restore: true);
  }

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
    switch (action) {
      case const CloseAction():
      // Since 4.0 the Android system back button no longer dismisses the flow
      // by default; keep closing it ourselves to preserve the old behaviour.
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
  void flowViewDidFailLoadingProducts(AdaptyUIFlowView view, AdaptyError error) {
    closePaymentScreen(true, view: view);
    _actor.handleFailure(Markers.ui, "Failed loading products", error, temporary: true);
  }

  @override
  void flowViewDidFailPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyError error) {
    closePaymentScreen(true, view: view);
    _actor.handleFailure(Markers.ui, "Failed purchase", error);
  }

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {
    // 4.0 folds the old rendering-failure callback into this one. Keep the
    // 3.x behaviour: log only, don't tear down — the view may still render,
    // and purchase/restore/product failures arrive via their own callbacks.
    log(Markers.ui).e(msg: "Adapty flow error", err: error);
  }

  @override
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) {
    closePaymentScreen(true, view: view);
    _actor.handleFailure(Markers.ui, "Failed restore", error, restore: true);
  }

  @override
  void flowViewDidSelectProduct(AdaptyUIFlowView view, String productId) {}

  @override
  void flowViewDidStartPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product) {}

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) {}

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {}

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {}

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) {
    // Since 4.0 a dismissed view is released natively and cannot be presented
    // again. This fires for every dismissal path, including swipe-down which
    // bypasses closePaymentScreen; drop the cache so the next open recreates
    // the view instead of presenting a spent one.
    if (_paymentView?.id == view.id) {
      _paymentView = null;
      _paymentViewForPlacementId = null;
    }
  }

  @override
  void flowViewDidReceiveAnalyticEvent(AdaptyUIFlowView view, String name, Map<String, dynamic> params) {}

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
