part of 'payment.dart';

const _embeddedSheetMountCheck = Duration(milliseconds: 700);
const _embeddedSheetMountAttempts = 3;

// Currently we have two Adapty SDK integrations, hence the interface.
// We are waiting for the flutter SDK to add support for android prorate modes.
// After that, we can drop the android SDK.
// This is handled through flutter platform channel (the other class).
class AdaptyPaymentChannel with Logging, PaymentChannel implements AdaptyUIFlowsEventsObserver {
  late final _stage = Core.get<StageStore>();
  late final _actor = Core.get<PaymentActor>(); // Circular dep
  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  late final _adapty = Adapty();
  late final _adaptyUi = AdaptyUI();

  AdaptyUIFlowView? _paymentView;
  String? _paymentViewForPlacementId;

  // Set while closePaymentScreen dismisses a view, so flowViewDidDisappear can
  // tell an app-initiated dismissal (already reported to the actor, possibly
  // as an error) from one the user or the flow performed natively.
  String? _dismissingViewId;

  // Wide iOS windows host the flow in our own floating sheet (see
  // AdaptyEmbeddedPaywallSheet) so its width is capped like the Android tablet
  // dialog; Adapty's presenter always covers the whole screen. Its events
  // still arrive through this observer, the SDK forwards them for embedded
  // views too.
  AdaptyFlow? _embeddedFlow;
  String? _embeddedFlowForPlacementId;
  bool _isEmbeddedPaywallVisible = false;
  // The mounted sheet of the current open, once the sheet host has shown it.
  _AdaptyEmbeddedPaywallSheetState? _embeddedSheet;
  // Bumped per embedded open. Each sheet carries the value it was built for,
  // so a sheet of an earlier open (still animating out, or shown late by the
  // host) is never mistaken for the current one.
  int _embeddedOpenSeq = 0;

  // Ids of views created through createFlowView. Any other view reporting
  // events is an embedded one, which must never be dismissed through Adapty.
  final _presentedViewIds = <String>{};

  bool _useEmbeddedSheet() {
    if (Core.act.platform != PlatformType.iOS) return false;
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return false;
    // Same boundary the sheet host uses to float a sheet instead of docking it.
    return view.physicalSize.width / view.devicePixelRatio >= minWidthFloatingSheet;
  }

  void _dropCachedView() {
    _paymentView = null;
    _paymentViewForPlacementId = null;
  }

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
      // Family is a separate Adapty app, so it ships its own fallbacks.
      final platform = Core.act.platform == PlatformType.iOS ? "ios" : "android";
      final assetId = Core.act.isFamily ? "family_$platform" : platform;
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
    if (_useEmbeddedSheet()) {
      _embeddedFlow = await _fetchFlow(m, placement);
      _embeddedFlowForPlacementId = placement.id;
      return;
    }
    _paymentView = await _createPaywall(m, placement);
    _paymentViewForPlacementId = placement.id;
  }

  @override
  showPaymentScreen(Marker m, Placement placement, {bool forceReload = false}) async {
    if (_useEmbeddedSheet()) return await _showEmbedded(m, placement, forceReload);

    if (forceReload || _paymentViewForPlacementId != placement.id || _paymentView == null) {
      _paymentView = await _createPaywall(m, placement);
      _paymentViewForPlacementId = placement.id;
    }

    try {
      await _paymentView!.present();
    } catch (_) {
      // AdaptyUIFlowView is single-use; drop the spent view so the next
      // open recreates it instead of re-presenting a view that already failed.
      _dropCachedView();
      rethrow;
    }
  }

  Future<void> _showEmbedded(Marker m, Placement placement, bool forceReload) async {
    // Already on screen (e.g. a double tap): a second request would be dropped
    // by the busy sheet host and then given up on, closing the visible one.
    if (_isEmbeddedPaywallVisible && _embeddedSheet != null) return;

    if (forceReload || _embeddedFlowForPlacementId != placement.id || _embeddedFlow == null) {
      _embeddedFlow = await _fetchFlow(m, placement);
      _embeddedFlowForPlacementId = placement.id;
    }
    final flow = _embeddedFlow!;
    // Like a presented view, fetch again for the next open.
    _embeddedFlow = null;
    _embeddedFlowForPlacementId = null;

    _isEmbeddedPaywallVisible = true;
    _embeddedSheet = null;
    final seq = ++_embeddedOpenSeq;
    await _requestEmbeddedSheet(m, flow, seq);
    unawaited(_ensureEmbeddedSheetMounted(m, flow, seq));
  }

  Future<void> _requestEmbeddedSheet(Marker m, AdaptyFlow flow, int seq) async {
    // Modal first: the sheet host reads it when the widget arrives and keeps
    // this sheet from being dragged away mid-purchase.
    await _modal.change(m, Modal.adaptyPaywall);
    await _modalWidget.change(
        m, (context) => AdaptyEmbeddedPaywallSheet(channel: this, flow: flow, openSeq: seq));
  }

  // The sheet host drops a request that arrives while another sheet is still
  // on screen (e.g. the weekly sheet closing itself to open the paywall).
  // Ask again until ours mounts; otherwise the actor stays "opened" forever.
  Future<void> _ensureEmbeddedSheetMounted(Marker m, AdaptyFlow flow, int seq) async {
    for (var attempt = 0; attempt < _embeddedSheetMountAttempts; attempt++) {
      await Future.delayed(_embeddedSheetMountCheck);
      if (seq != _embeddedOpenSeq || !_isEmbeddedPaywallVisible || _embeddedSheet != null) return;
      await _requestEmbeddedSheet(m, flow, seq);
    }
    await Future.delayed(_embeddedSheetMountCheck);
    if (seq != _embeddedOpenSeq || !_isEmbeddedPaywallVisible || _embeddedSheet != null) return;
    log(m).e(msg: "Adapty: embedded paywall sheet never mounted, giving up");
    // Not a payment error the user caused: just let the paywall be opened again.
    await closePaymentScreen(false);
  }

  void handleEmbeddedPaywallMounted(_AdaptyEmbeddedPaywallSheetState sheet) {
    if (sheet.widget.openSeq == _embeddedOpenSeq && _isEmbeddedPaywallVisible) {
      _embeddedSheet = sheet;
      return;
    }
    // Shown by the host after its open was already closed or replaced.
    WidgetsBinding.instance.addPostFrameCallback((_) => sheet.dismiss());
  }

  // The sheet went away without closePaymentScreen (tap outside, back
  // gesture): report the close, or the actor keeps thinking it is open. Only
  // the current open's sheet counts; an earlier one finishing its exit
  // animation must not close a paywall that was just reopened.
  void handleEmbeddedPaywallDisposed(_AdaptyEmbeddedPaywallSheetState sheet) {
    if (_embeddedSheet != sheet) return;
    _embeddedSheet = null;
    if (!_isEmbeddedPaywallVisible) return;
    unawaited(closePaymentScreen(false));
  }

  @override
  closePaymentScreen(bool isError, {AdaptyUIFlowView? view}) async {
    if (_isEmbeddedPaywallVisible || (view != null && !_presentedViewIds.contains(view.id))) {
      // An embedded view is owned by our sheet: pop the sheet, never ask
      // Adapty to dismiss it.
      // Cleared before popping, so the sheet's dispose does not report again.
      _isEmbeddedPaywallVisible = false;
      // Pop our sheet directly. With no sheet mounted yet there is nothing to
      // pop, and clearing the shared modal value instead would make the host
      // pop whatever other sheet is on screen; a late mount dismisses itself.
      _embeddedSheet?.dismiss();
      await _actor.handleScreenClosed(Markers.ui, isError: isError);
      return;
    }

    final dismissing = view ?? _paymentView;
    // Only invalidate the cache when it holds the view being dismissed —
    // preload() may have already cached a fresh view for another placement.
    if (view == null || _paymentView?.id == view.id) _dropCachedView();
    _dismissingViewId = dismissing?.id;
    await dismissing?.dismiss();
    await _actor.handleScreenClosed(Markers.ui, isError: isError);
  }

  Future<AdaptyUIFlowView> _createPaywall(Marker m, Placement placement) async {
    final flow = await _fetchFlow(m, placement);
    // Since 4.0 a flow is localized when its view is built; without an explicit
    // locale it renders in `en` regardless of device language. The value must
    // be a localization id as configured in the dashboard (bare language code,
    // e.g. `es`): unlike the 3.x fetch-time matching, 4.0 resolves it with an
    // exact lookup, so a region-tagged `es_es` silently falls back to English.
    final view = await _adaptyUi.createFlowView(
      flow: flow,
      locale: I18n.languageOnly,
      preloadProducts: false,
    );
    _presentedViewIds.add(view.id);
    return view;
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
        // Adapty 4 can report a Success whose profile carries no active access
        // level (e.g. a replayed or expired transaction). Running checkout on
        // that profile 400s at the backend and surfaces a spurious "payment
        // failed". Treat it as "no entitlement granted": leave the paywall open
        // and skip checkout. The backend still rejects such a profile as
        // defense in depth. See issue-tracker #376.
        if (!_hasActiveAccess(profile)) {
          log(Markers.ui)
              .w("Adapty: purchase success without active access level, ignoring");
          break;
        }
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
    // Same guard as purchase: a restore that granted no active access level
    // must not run checkout (it would 400 and show "payment failed"). Leave
    // the paywall open so the user can still buy. See issue-tracker #376.
    if (!_hasActiveAccess(profile)) {
      log(Markers.ui).w("Adapty: restore without active access level");
      _showRestoreNotActive(view);
      return;
    }
    closePaymentScreen(false, view: view);
    _actor.checkoutSuccessfulPayment(profile.profileId, restore: true);
  }

  // Tells the user why restore did nothing. Uses the Adapty dialog because our
  // own modals render beneath the native paywall. One message covers both "never
  // bought" and "expired": the profile's access levels belong to the Blokada
  // account, not the store account being restored, so they can't tell those
  // apart. See issue-tracker #395.
  Future<void> _showRestoreNotActive(AdaptyUIFlowView view) async {
    // The Adapty dialog only resolves views Adapty presented; an embedded one
    // sits in our own sheet, where a regular dialog renders on top.
    final sheet = _embeddedSheet;
    if (sheet != null && !_presentedViewIds.contains(view.id)) {
      sheet.showMessage(
        title: "payment action restore".i18n,
        content: "error restore not found".i18n,
        closeTitle: "universal action close".i18n,
      );
      return;
    }
    try {
      await view.showDialog(
        title: "payment action restore".i18n,
        content: "error restore not found".i18n,
        primaryActionTitle: "universal action close".i18n,
      );
    } catch (e, s) {
      log(Markers.ui).e(msg: "Adapty: failed showing restore dialog", err: e, stack: s);
    }
  }

  // Adapty grants entitlement through access levels; a Success/restore whose
  // profile has none active carries no entitlement (see #376).
  bool _hasActiveAccess(AdaptyProfile profile) =>
      profile.accessLevels.values.any((level) => level.isActive);

  @override
  Future<List<StoreSubscription>> fetchActiveSubscriptions(Marker m) async {
    final profile = await _adapty.getProfile();
    return profile.accessLevels.values
        .where((level) => level.isActive)
        .map((level) => StoreSubscription(
              accessLevelId: level.id,
              store: level.store,
              willRenew: level.willRenew,
              expiresAt: level.expiresAt,
              customerUserId: profile.customerUserId,
            ))
        .toList();
  }

  @override
  Future<String?> restorePurchases(Marker m) async {
    final profile = await _adapty.restorePurchases();
    return _hasActiveAccess(profile) ? profile.profileId : null;
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
    // The sheet owns an embedded view's lifecycle and reports its close.
    if (!_presentedViewIds.remove(view.id)) return;
    // Since 4.0 a dismissed view is released natively and cannot be presented
    // again. This fires for every dismissal path, including swipe-down which
    // bypasses closePaymentScreen; drop the cache so the next open recreates
    // the view instead of presenting a spent one.
    if (_paymentView?.id == view.id) _dropCachedView();
    if (_dismissingViewId == view.id) {
      // closePaymentScreen initiated this dismissal and reports the close
      // itself, with the right isError.
      _dismissingViewId = null;
      return;
    }
    // The dismissal bypassed closePaymentScreen (swipe-down, flow-internal
    // close): reset the actor, or _isOpened stays true and the paywall can
    // never be reopened. handleScreenClosed no-ops when already closed.
    _actor.handleScreenClosed(Markers.ui, isError: false);
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
