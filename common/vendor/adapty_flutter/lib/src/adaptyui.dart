// ignore_for_file: deprecated_member_use_from_same_package
part of 'adapty.dart';

class AdaptyUI {
  static final AdaptyUI _instance = AdaptyUI._internal();

  factory AdaptyUI() => _instance;

  AdaptyUI._internal();

  AdaptyUIEventsProxy _eventsProxy = AdaptyUIEventsProxy();

  // ignore: unused_field
  AdaptyUISystemRequestsHandler? _systemRequestsHandler;
  // ignore: unused_field
  AdaptyUIObserverModeResolver? _observerModeResolver;

  /// Use this method to set the AdaptyUI system requests handler.
  void setSystemRequestsHandler(AdaptyUISystemRequestsHandler handler) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setSystemRequestsHandler()');
    _systemRequestsHandler = handler;
  }

  /// Use this method to set the AdaptyUI observer mode resolver.
  void setObserverModeResolver(AdaptyUIObserverModeResolver resolver) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setObserverModeResolver()');
    _observerModeResolver = resolver;
  }

  void registerFlowEventsListener(AdaptyUIFlowsEventsObserver observer, String viewId) {
    _eventsProxy.registerFlowEventsListener(observer, viewId);
  }

  void unregisterFlowEventsListener(String viewId) {
    _eventsProxy.unregisterFlowEventsListener(viewId);
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  void registerOnboardingEventsListener(AdaptyUIOnboardingsEventsObserver observer, String viewId) {
    _eventsProxy.registerOnboardingEventsListener(observer, viewId);
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  void unregisterOnboardingEventsListener(String viewId) {
    _eventsProxy.unregisterOnboardingEventsListener(viewId);
  }

  /// Use this method to set the AdaptyUI flows events observer.
  ///
  /// Pass `null` to detach the previously set observer (e.g. on cleanup),
  /// so the SDK no longer holds a reference to it.
  void setFlowsEventsObserver(AdaptyUIFlowsEventsObserver? observer) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setFlowsEventsObserver()');
    _eventsProxy.flowsEventsObserver = observer;
  }

  /// Use this method to set the AdaptyUI onboardings events observer.
  ///
  /// Pass `null` to detach the previously set observer (e.g. on cleanup),
  /// so the SDK no longer holds a reference to it.
  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  void setOnboardingsEventsObserver(AdaptyUIOnboardingsEventsObserver? observer) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setOnboardingsEventsObserver()');
    _eventsProxy.onboardingsEventsObserver = observer;
  }

  /// Right after receiving ``AdaptyFlow``, you can create the corresponding ``AdaptyUIFlowView`` to present it afterwards.
  ///
  /// **Parameters**
  /// - [flow]: an [AdaptyFlow] object, for which you are trying to get a controller.
  /// - [locale]: the identifier of the localization to render the flow with, e.g. `en`, `es`, `fr`.
  /// If you don't pass it, the view is rendered in `en`, falling back to the flow's default
  /// localization when the flow has no `en`. Asking for a localization the flow does not have
  /// falls back to the flow default as well, without an error. Strings missing from the chosen
  /// localization are filled in from the default one.
  /// - [preloadProducts]: If you pass `true`, `AdaptyUI` will automatically prefetch the required products at the moment of view assembly.
  /// - [androidEnableSafeArea]: Android only. If `true`, the flow view applies the safe-area insets as paddings. Has no effect on iOS. Defaults to `true`.
  /// - [productPurchaseParams]: A map that contains purchase parameters for specific products.
  /// The key is an [AdaptyProductIdentifier] and the value is [AdaptyPurchaseParameters] containing purchase-specific configuration.
  ///
  /// **Returns**
  /// - an [AdaptyUIFlowView] object, representing the requested flow screen.
  Future<AdaptyUIFlowView> createFlowView({
    required AdaptyFlow flow,
    String? locale,
    Duration? loadTimeout,
    bool preloadProducts = false,
    bool androidEnableSafeArea = true,
    Map<String, String>? customTags,
    Map<String, DateTime>? customTimers,
    Map<String, AdaptyCustomAsset>? customAssets,
    Map<AdaptyProductIdentifier, AdaptyPurchaseParameters>? productPurchaseParams,
  }) async {
    return Adapty()._invokeMethod<AdaptyUIFlowView>(
      Method.createFlowView,
      (data) {
        final viewMap = data as Map<String, dynamic>;
        return AdaptyUIFlowViewJSONBuilder.fromJsonValue(viewMap);
      },
      {
        Argument.flow: flow.jsonValue,
        if (locale != null) Argument.locale: locale,
        Argument.preloadProducts: preloadProducts,
        Argument.enableSafeAreaPaddings: androidEnableSafeArea,
        if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
        if (customTags != null) Argument.customTags: customTags,
        if (customTimers != null)
          Argument.customTimers: customTimers.map((key, value) => MapEntry(
                key,
                value.toAdaptyValidString(),
              )),
        if (customAssets != null)
          Argument.customAssets: customAssets.entries
              .map((entry) => {
                    Argument.id: entry.key,
                    ...entry.value.jsonValue,
                  })
              .toList(),
        if (productPurchaseParams != null)
          Argument.productPurchaseParameters: AdaptyProductIdentifier.convertProductPurchaseParamsToJson(
            productPurchaseParams,
          ),
      },
    );
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<AdaptyUIOnboardingView> createOnboardingView({
    required AdaptyOnboarding onboarding,
    AdaptyWebPresentation externalUrlsPresentation = AdaptyWebPresentation.inAppBrowser,
  }) async {
    return Adapty()._invokeMethod<AdaptyUIOnboardingView>(
      Method.createOnboardingView,
      (data) {
        final viewMap = data as Map<String, dynamic>;
        return AdaptyUIOnboardingViewJSONBuilder.fromJsonValue(viewMap);
      },
      {
        Argument.onboarding: onboarding.jsonValue,
        Argument.externalUrlsPresentation: externalUrlsPresentation.jsonValue,
      },
    );
  }

  /// Call this function if you wish to present the view.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] object, for which is representing the view.
  Future<void> presentFlowView(
    AdaptyUIFlowView view, {
    AdaptyUIIOSPresentationStyle iosPresentationStyle = AdaptyUIIOSPresentationStyle.fullScreen,
  }) async {
    return Adapty()._invokeMethod<void>(
      Method.presentFlowView,
      (data) => null,
      {
        Argument.id: view.id,
        Argument.iosPresentationStyle: iosPresentationStyle.jsonValue,
      },
    );
  }

  /// Call this function if you wish to present the view.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIOnboardingView] object, for which is representing the view.
  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<void> presentOnboardingView(
    AdaptyUIOnboardingView view, {
    AdaptyUIIOSPresentationStyle iosPresentationStyle = AdaptyUIIOSPresentationStyle.fullScreen,
  }) async {
    return Adapty()._invokeMethod<void>(
      Method.presentOnboardingView,
      (data) => null,
      {
        Argument.id: view.id,
        Argument.iosPresentationStyle: iosPresentationStyle.jsonValue,
      },
    );
  }

  /// Call this function if you wish to dismiss the view.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] object, for which is representing the view.
  Future<void> dismissFlowView(AdaptyUIFlowView view) async {
    return Adapty()._invokeMethod<void>(
      Method.dismissFlowView,
      (data) => null,
      {Argument.id: view.id, Argument.destroy: true},
    );
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<void> dismissOnboardingView(AdaptyUIOnboardingView view) async {
    return Adapty()._invokeMethod<void>(
      Method.dismissOnboardingView,
      (data) => null,
      {Argument.id: view.id, Argument.destroy: true},
    );
  }

  /// Call this function if you wish to present the dialog.
  ///
  /// **Parameters**
  /// - [title]: The title of the dialog.
  /// - [content]: Descriptive text that provides additional details about the reason for the dialog.
  /// - [primaryActionTitle]: The action title to display as part of the dialog. If you provide two actions, be sure the `defaultAction` cancels the operation and leaves things unchanged.
  /// - [secondaryActionTitle]: The secondary action title to display as part of the dialog.
  Future<AdaptyUIDialogActionType> showDialog(
    String viewId, {
    required String title,
    required String content,
    required String primaryActionTitle,
    String? secondaryActionTitle,
  }) async {
    final dialog = AdaptyUIDialog(
      title: title,
      content: content,
      primaryActionTitle: primaryActionTitle,
      secondaryActionTitle: secondaryActionTitle,
    );

    return await Adapty()._invokeMethod<AdaptyUIDialogActionType>(
      Method.showDialog,
      (data) => AdaptyUIDialogActionTypeJSONBuilder.fromJsonValue(data as String),
      {
        Argument.id: viewId,
        Argument.configuration: dialog.jsonValue,
      },
    );
  }

  /// Opens a URL natively (external or in-app browser). Backs the default
  /// handling of the flow `open_url` action; can also be called directly.
  Future<void> openUrl(
    String url, {
    AdaptyWebPresentation openIn = AdaptyWebPresentation.externalBrowser,
  }) async {
    return Adapty()._invokeMethod<void>(
      Method.openUrl,
      (data) => null,
      {
        Argument.url: url,
        Argument.openIn: openIn.jsonValue,
      },
    );
  }

  /// Requests the native in-app review prompt (StoreKit on iOS). Best-effort:
  /// the OS decides whether to actually show it. Backs the default handling of
  /// the flow app-review request; can also be called directly.
  Future<void> requestAppReview() async {
    return Adapty()._invokeMethod<void>(
      Method.requestAppReview,
      (data) => null,
      const {},
    );
  }
}
