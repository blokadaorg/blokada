// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async' show StreamController;
import 'dart:convert' show json;
import 'package:flutter/services.dart';

import 'adapty_logger.dart';

import 'adaptyui_events_proxy.dart';
import 'constants/argument.dart';
import 'constants/method.dart';

import 'models/adapty_error.dart';
import 'models/adapty_log_level.dart';
import 'models/adapty_onboarding.dart';
import 'models/adapty_product_identifier.dart';
import 'models/adapty_profile.dart';
import 'models/adapty_flow.dart';
import 'models/adapty_flow_paywall.dart';
import 'models/adapty_flow_fetch_policy.dart';
import 'models/adapty_purchase_parameters.dart';
import 'models/adapty_profile_parameters.dart';
import 'models/adapty_purchase_result.dart';
import 'models/adapty_paywall_product.dart';
import 'models/adapty_sdk_native.dart';
import 'models/adapty_configuration.dart';
import 'models/adapty_error_code.dart';
import 'models/adapty_refund_preference.dart';
import 'models/adapty_installation_details.dart';
import 'models/adapty_customer_identity.dart';
import 'models/adapty_web_presentation.dart';

import 'adaptyui_observer.dart';
import 'adaptyui_system_requests_handler.dart';
import 'adaptyui_observer_mode_resolver.dart';

import 'models/adaptyui/adaptyui_action.dart';
import 'models/adaptyui/adaptyui_dialog.dart';
import 'models/adaptyui/adaptyui_ios_presentation_style.dart';
import 'models/adaptyui/adaptyui_onboarding_meta.dart';
import 'models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import 'models/adaptyui/adaptyui_onboarding_view.dart';
import 'models/adaptyui/adaptyui_onboardings_analytics_event.dart';
import 'models/adaptyui/adaptyui_flow_view.dart';
import 'models/adaptyui/adaptyui_permission.dart';

import 'models/custom_assets/adaptyui_custom_assets.dart';

import 'models/private/json_builder.dart';
import 'adapty_version.dart';

part 'adaptyui.dart';

class Adapty {
  static final Adapty _instance = Adapty._internal();

  factory Adapty() => _instance;

  Adapty._internal();

  static String get sdkVersion => adaptySDKVersion;

  static const String _channelName = 'flutter.adapty.com/adapty';
  static const MethodChannel _channel = const MethodChannel(_channelName);

  StreamController<AdaptyProfile> _didUpdateProfileController = StreamController.broadcast();
  Stream<AdaptyProfile> get didUpdateProfileStream => _didUpdateProfileController.stream;

  StreamController<AdaptyInstallationDetails> _onUpdateInstallationDetailsSuccessController = StreamController.broadcast();
  Stream<AdaptyInstallationDetails> get onUpdateInstallationDetailsSuccessStream => _onUpdateInstallationDetailsSuccessController.stream;

  StreamController<AdaptyError> _onUpdateInstallationDetailsFailController = StreamController.broadcast();
  Stream<AdaptyError> get onUpdateInstallationDetailsFailStream => _onUpdateInstallationDetailsFailController.stream;

  /// Returns true if the native SDK is activated and the plugin is activated.
  Future<bool> isActivated() async {
    return await _invokeMethod<bool>(
      Method.isActivated,
      (data) => data as bool,
      null,
    );
  }

  /// Use this method to initialize the plugin after hot restart. Please check isActivated before calling this method. Don't use this method in release builds.
  void setupAfterHotRestart() {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'Adapty.setupAfterHotRestart()');
    _channel.setMethodCallHandler(_tryHandleIncomingMethodCall);
  }

  /// Use this method to initialize the Adapty SDK.
  Future<void> activate({
    required AdaptyConfiguration configuration,
  }) async {
    _channel.setMethodCallHandler(_tryHandleIncomingMethodCall);

    await _invokeMethod<void>(
      Method.activate,
      (data) => null,
      {
        Argument.configuration: configuration.jsonValue,
      },
    );
  }

  /// Set to the most appropriate level of logging.
  Future<void> setLogLevel(AdaptyLogLevel value) {
    AdaptyLogger.logLevel = value;

    return _invokeMethod<void>(
      Method.setLogLevel,
      (data) => null,
      {
        Argument.value: value.name,
      },
    );
  }

  Future<AdaptyInstallationStatus> getCurrentInstallationStatus() {
    return _invokeMethod<AdaptyInstallationStatus>(
      Method.getCurrentInstallationStatus,
      (data) {
        final installationDetailsMap = data as Map<String, dynamic>;
        return AdaptyInstallationStatusJSONBuilder.fromJsonValue(installationDetailsMap);
      },
      null,
    );
  }

  /// The main function for getting a user profile. Allows you to define the level of access, as well as other parameters.
  ///
  /// The getProfile method provides the most up-to-date result as it always tries to query the API.
  /// If for some reason (e.g. no internet connection), the Adapty SDK fails to retrieve information from the server, the data from cache will be returned.
  /// It is also important to note that the Adapty SDK updates AdaptyProfile cache on a regular basis, in order to keep this information as up-to-date as possible.
  ///
  /// **Returns:**
  /// - the result containing a [AdaptyProfile] object.
  /// This model contains info about access levels, subscriptions, and non-subscription purchases. Generally, you have to check only access level status to determine whether the user has premium access to the app.
  Future<AdaptyProfile> getProfile() {
    return _invokeMethod<AdaptyProfile>(
      Method.getProfile,
      (data) {
        final profileMap = data as Map<String, dynamic>;
        return AdaptyProfileJSONBuilder.fromJsonValue(profileMap);
      },
      null,
    );
  }

  /// You can set optional attributes such as email, phone number, etc, to the user of your app.
  /// You can then use attributes to create user [segments](https://docs.adapty.io/v2.0/docs/segments) or just view them in CRM.
  ///
  /// **Parameters:**
  /// - [params]: use [AdaptyProfileParametersBuilder] to build this object.
  Future<void> updateProfile(AdaptyProfileParameters params) {
    return _invokeMethod<void>(
      Method.updateProfile,
      (data) => null,
      {
        Argument.params: params.jsonValue,
      },
    );
  }

  /// Use this method for identifying user with it’s user id in your system.
  ///
  /// If you don’t have a user id on SDK configuration, you can set it later at any time with `.identify()` method.
  /// The most common cases are after registration/authorization when the user switches from being an anonymous user to an authenticated user.
  ///
  /// **Parameters:**
  /// - [customerUserId]: User identifier in your system.
  /// - [iosAppAccountToken]: iOS App Account Token (UUID string)
  /// - [androidObfuscatedAccountId]: The obfuscated account identifier (use for Android), [read more](https://developer.android.com/google/play/billing/developer-payload#attribute).
  Future<void> identify(
    String customerUserId, {
    String? iosAppAccountToken,
    String? androidObfuscatedAccountId,
  }) {
    final parameters = AdaptyCustomerIdentity(
      iosAppAccountToken,
      androidObfuscatedAccountId,
    );

    return _invokeMethod<void>(
      Method.identify,
      (data) => null,
      {
        Argument.customerUserId: customerUserId,
        if (!parameters.isEmpty) Argument.parameters: parameters.jsonValue,
      },
    );
  }

  /// This method enables you to retrieve the paywall from the Default Audience without having to wait for the Adapty SDK to send all the user information required for segmentation to the server.
  ///
  /// **Parameters:**
  /// - [placementId]: the identifier of the desired placement. This is the value you specified when you created the placement in the Adapty Dashboard.
  /// - [locale]: has no effect. Starting with 4.0.0 a flow is localized when its view is built,
  /// so pass the locale to `AdaptyUI.createFlowView` or `AdaptyUIFlowPlatformView` instead.
  /// - [fetchPolicy]: the fetch policy of the paywall.
  ///
  /// **Returns:**
  /// - the [AdaptyFlow] object. This model contains the list of the products ids, flow’s identifier, custom payload, and several other properties.
  Future<AdaptyFlow> getFlowForDefaultAudience({
    required String placementId,
    @Deprecated(
      'Has no effect for flows. Starting Adapty SDK 4.0.0 the locale is applied when the flow view is built — '
      'pass it to AdaptyUI.createFlowView or AdaptyUIFlowPlatformView instead.',
    )
    String? locale,
    AdaptyFlowFetchPolicy? fetchPolicy,
  }) {
    _warnIfFlowLocalePassed(locale, 'getFlowForDefaultAudience');

    return _invokeMethod<AdaptyFlow>(
      Method.getFlowForDefaultAudience,
      (data) {
        final flowMap = data as Map<String, dynamic>;
        return AdaptyFlowJSONBuilder.fromJsonValue(flowMap);
      },
      {
        Argument.placementId: placementId,
        if (locale != null) Argument.locale: locale,
        if (fetchPolicy != null) Argument.fetchPolicy: fetchPolicy.jsonValue,
      },
    );
  }

  /// Adapty allows you remotely configure the products that will be displayed in your app.
  /// This way you don’t have to hardcode the products and can dynamically change offers or run A/B tests without app releases.
  ///
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/v2.0/docs/displaying-products)
  ///
  /// **Parameters:**
  /// - [placementId]: the identifier of the desired placement. This is the value you specified when you created the placement in the Adapty Dashboard.
  /// - [locale]: has no effect. Starting with 4.0.0 a flow is localized when its view is built,
  /// so pass the locale to `AdaptyUI.createFlowView` or `AdaptyUIFlowPlatformView` instead.
  /// - [fetchPolicy]: by default SDK will try to load data from server and will return cached data in case of failure. Otherwise use `.returnCacheDataElseLoad` to return cached data if it exists.
  /// - [loadTimeout]: the timeout for the paywall loading.
  ///
  /// **Returns:**
  /// - the [AdaptyFlow] object. This model contains the list of the products ids, flow’s identifier, custom payload, and several other properties.
  Future<AdaptyFlow> getFlow({
    required String placementId,
    @Deprecated(
      'Has no effect for flows. Starting Adapty SDK 4.0.0 the locale is applied when the flow view is built — '
      'pass it to AdaptyUI.createFlowView or AdaptyUIFlowPlatformView instead.',
    )
    String? locale,
    AdaptyFlowFetchPolicy? fetchPolicy,
    Duration? loadTimeout,
  }) {
    _warnIfFlowLocalePassed(locale, 'getFlow');

    return _invokeMethod<AdaptyFlow>(
      Method.getFlow,
      (data) {
        final flowMap = data as Map<String, dynamic>;
        return AdaptyFlowJSONBuilder.fromJsonValue(flowMap);
      },
      {
        Argument.placementId: placementId,
        if (locale != null) Argument.locale: locale,
        if (fetchPolicy != null) Argument.fetchPolicy: fetchPolicy.jsonValue,
        if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
      },
    );
  }

  /// Once you have a [AdaptyFlow], fetch corresponding products array using this method.
  ///
  /// **Parameters:**
  /// - flow: an [AdaptyFlow] for which you want to get a products.
  ///
  /// **Returns:**
  /// - a result containing the [AdaptyPaywallProduct] objects array. You can present them in your UI.
  Future<List<AdaptyPaywallProduct>> getPaywallProducts({
    required AdaptyFlow flow,
  }) {
    return _invokeMethod<List<AdaptyPaywallProduct>>(
      Method.getPaywallProducts,
      (data) {
        final paywallProductsMap = data as List<dynamic>;
        return paywallProductsMap.map((e) => AdaptyPaywallProductJSONBuilder.fromJsonValue(e)).toList();
      },
      {
        Argument.flow: flow.jsonValue,
      },
    );
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<AdaptyOnboarding> getOnboarding({
    required String placementId,
    String? locale,
    AdaptyFlowFetchPolicy? fetchPolicy,
    Duration? loadTimeout,
  }) {
    return _invokeMethod<AdaptyOnboarding>(
      Method.getOnboarding,
      (data) {
        final onboardingMap = data as Map<String, dynamic>;
        return AdaptyOnboardingJSONBuilder.fromJsonValue(onboardingMap);
      },
      {
        Argument.placementId: placementId,
        if (locale != null) Argument.locale: locale,
        if (fetchPolicy != null) Argument.fetchPolicy: fetchPolicy.jsonValue,
        if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
      },
    );
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<AdaptyOnboarding> getOnboardingForDefaultAudience({
    required String placementId,
    String? locale,
    AdaptyFlowFetchPolicy? fetchPolicy,
  }) {
    return _invokeMethod<AdaptyOnboarding>(
      Method.getOnboardingForDefaultAudience,
      (data) {
        final onboardingMap = data as Map<String, dynamic>;
        return AdaptyOnboardingJSONBuilder.fromJsonValue(onboardingMap);
      },
      {
        Argument.placementId: placementId,
        if (locale != null) Argument.locale: locale,
        if (fetchPolicy != null) Argument.fetchPolicy: fetchPolicy.jsonValue,
      },
    );
  }

  /// To make the purchase, you have to call this method.
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/docs/making-purchases)
  ///
  /// **Parameters:**
  /// - [product]: an [AdaptyPaywallProduct] object retrieved from the paywall.
  /// - [parameters]: an [AdaptyPurchaseParameters] object used to pass additional parameters to the purchase.
  ///
  /// **Returns:**
  /// - The [AdaptyPurchaseResult] object. This model contains info about the purchase result.
  Future<AdaptyPurchaseResult> makePurchase({
    required AdaptyPaywallProduct product,
    AdaptyPurchaseParameters? parameters,
  }) {
    return _invokeMethod<AdaptyPurchaseResult>(
      Method.makePurchase,
      (data) {
        final purchaseResultMap = data as Map<String, dynamic>;
        return AdaptyPurchaseResultJSONBuilder.fromJsonValue(purchaseResultMap);
      },
      {
        Argument.product: product.jsonValue,
        if (parameters != null) Argument.parameters: parameters.jsonValue,
      },
    );
  }

  /// To restore purchases, you have to call this method.
  ///
  /// **Returns:**
  /// - A result containing the AdaptyProfile object. This model contains info about access levels, subscriptions, and non-subscription purchases.
  /// Generally, you have to check only access level status to determine whether the user has premium access to the app.
  Future<AdaptyProfile> restorePurchases() {
    return _invokeMethod<AdaptyProfile>(
      Method.restorePurchases,
      (data) {
        final profileMap = data as Map<String, dynamic>;
        return AdaptyProfileJSONBuilder.fromJsonValue(profileMap);
      },
      null,
    );
  }

  /// You can set integration identifiers for the profile, using method.
  ///
  /// **Parameters:**
  /// - [key]: a identifier of the integration.
  /// - [value]: a value of the integration identifier.
  Future<void> setIntegrationIdentifier({
    required String key,
    required String value,
  }) {
    return _invokeMethod<void>(
      Method.setIntegrationIdentifiers,
      (data) => null,
      {
        Argument.keyValues: {key: value},
      },
    );
  }

  /// You can set attribution data for the profile, using method.
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/docs/attribution-integration)
  ///
  /// **Parameters:**
  /// - [attribution]: a map containing attribution (conversion) data.
  /// - [source]: a source of attribution.
  Future<void> updateAttribution(
    Map attribution, {
    required String source,
  }) {
    return _invokeMethod<void>(
      Method.updateAttribution,
      (data) => null,
      {
        Argument.attribution: json.encode(attribution),
        Argument.source: source,
      },
    );
  }

  /// Call this method to notify Adapty SDK, that particular paywall was shown to user.
  ///
  /// Adapty helps you to measure the performance of the paywalls.
  /// We automatically collect all the metrics related to purchases except for paywall views.
  /// This is because only you know when the flow was shown to a customer. Whenever you show a flow to your user, call .logShowFlow(flow: flow) to log the event, and it will be accumulated in the flow metrics.
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/v2.0/docs/ios-displaying-products#paywall-analytics)
  ///
  /// **Parameters:**
  /// - [flow]: An [AdaptyFlow] object.
  Future<void> logShowFlow({required AdaptyFlow flow}) {
    return _invokeMethod<void>(
      Method.logShowFlow,
      (data) => null,
      {
        Argument.flow: flow.jsonValue,
      },
    );
  }

  /// In Observer mode, Adapty SDK doesn’t know, where the purchase was made from.
  /// If you display products using our [Paywalls](https://docs.adapty.io/v2.0/docs/paywall) or [A/B Tests](https://docs.adapty.io/v2.0/docs/ab-test), you can manually assign variation to the purchase.
  /// After doing this, you’ll be able to see metrics in Adapty Dashboard.
  ///
  /// **Parameters:**
  /// - [transactionId]: A string identifier of your purchased transaction [SKPaymentTransaction](https://developer.apple.com/documentation/storekit/skpaymenttransaction) (SK1) or [Transaction](https://developer.apple.com/documentation/storekit/transaction) (SK2) for iOS or string identifier (`purchase.getOrderId()`) of the purchase, where the purchase is an instance of the billing library Purchase class for Android.
  /// - [variationId]: A string identifier of variation. You can get it using the variationId property of AdaptyFlow / AdaptyFlowPaywall.
  Future<void> reportTransaction({
    required String transactionId,
    String? variationId,
  }) {
    return _invokeMethod<void>(
      Method.reportTransaction,
      (data) => null,
      {
        Argument.transactionId: transactionId,
        if (variationId != null) Argument.variationId: variationId,
      },
    );
  }

  /// To set fallback paywalls, use this method. You should pass exactly the same payload you’re getting from Adapty backend. You can copy it from Adapty Dashboard.
  ///
  /// Adapty allows you to provide fallback paywalls that will be used when a user opens the app for the first time and there’s no internet connection or in the rare case when Adapty backend is down and there’s no cache on the device.
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/v2.0/docs/ios-displaying-products#fallback-paywalls)
  ///
  /// **Parameters:**
  /// - [assetId]: a path to the asset file with fallback paywalls.
  Future<void> setFallback(String assetId) {
    return _invokeMethod<void>(
      Method.setFallback,
      (data) => null,
      {
        Argument.assetId: assetId,
      },
    );
  }

  /// You can logout the user anytime by calling this method.
  Future<void> logout() {
    return _invokeMethod<void>(Method.logout, (data) => null, null);
  }

  Future<String> createWebPaywallUrl({
    AdaptyFlowPaywall? paywall,
    AdaptyPaywallProduct? product,
  }) async {
    Map<String, dynamic>? arguments;

    if (paywall != null) {
      arguments = {Argument.paywall: paywall.jsonValue};
    } else if (product != null) {
      arguments = {Argument.product: product.jsonValue};
    } else {
      throw AdaptyError(
        'Either paywall or product parameter must be provided',
        AdaptyErrorCode.wrongParam,
        null,
      );
    }

    return _invokeMethod<String>(
      Method.createWebPaywallUrl,
      (data) => data as String,
      arguments,
    );
  }

  Future<void> openWebPaywall({
    AdaptyFlowPaywall? paywall,
    AdaptyPaywallProduct? product,
    AdaptyWebPresentation openIn = AdaptyWebPresentation.externalBrowser,
  }) async {
    Map<String, dynamic>? arguments = {Argument.openIn: openIn.jsonValue};

    if (paywall != null) {
      arguments[Argument.paywall] = paywall.jsonValue;
    } else if (product != null) {
      arguments[Argument.product] = product.jsonValue;
    } else {
      throw AdaptyError(
        'Either paywall or product parameter must be provided',
        AdaptyErrorCode.wrongParam,
        null,
      );
    }

    return _invokeMethod<void>(
      Method.openWebPaywall,
      (data) => null,
      arguments,
    );
  }

  // ––––––– IOS ONLY METHODS –––––––

  Future<void> updateCollectingRefundDataConsent(bool consent) {
    if (!AdaptySDKNative.isIOS) return Future.value();
    return _invokeMethod<void>(
      Method.updateCollectingRefundDataConsent,
      (data) => null,
      {
        Argument.consent: consent,
      },
    );
  }

  Future<void> updateRefundPreference(AdaptyRefundPreference refundPreference) {
    if (!AdaptySDKNative.isIOS) return Future.value();
    return _invokeMethod<void>(
      Method.updateRefundPreference,
      (data) => null,
      {Argument.refundPreference: refundPreference.jsonValue},
    );
  }

  /// Call this method to have StoreKit present a sheet enabling the user to redeem codes provided by your app.
  Future<void> presentCodeRedemptionSheet() {
    if (!AdaptySDKNative.isIOS) return Future.value();
    return _invokeMethod<void>(Method.presentCodeRedemptionSheet, (data) => null, null);
  }

  // ––––––– INTERNAL –––––––

  /// The `locale` argument of the flow-fetching methods is a leftover from 3.x,
  /// where a paywall was localized at fetch time. Since 4.0.0 a flow is localized
  /// when its view is built, so neither iOS nor Android does anything with it.
  /// The annotation alone is not enough — the Dart analyzer does not report
  /// deprecated named parameters at call sites — so warn at runtime instead of
  /// dropping the value silently.
  void _warnIfFlowLocalePassed(String? locale, String method) {
    if (locale == null) return;

    AdaptyLogger.write(
      AdaptyLogLevel.warn,
      'Adapty.$method(locale: "$locale"): the locale is ignored for flows. '
      'Since Adapty SDK 4.0.0 a flow is localized when its view is built — '
      'pass the locale to AdaptyUI.createFlowView or AdaptyUIFlowPlatformView instead.',
    );
  }

  Future<T> _invokeMethod<T>(
    String method,
    T Function(dynamic) responseParser,
    Map<String, dynamic>? arguments,
  ) async {
    final stamp = AdaptyLogger.stamp;
    final stringArguments = json.encode(arguments ?? {});
    AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] --> Adapty.$method(), Args: $stringArguments');

    try {
      final stringResult = await _channel.invokeMethod<String>(method, stringArguments);
      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.$method(), Result: $stringResult');

      if (stringResult == null) {
        throw AdaptyError('Adapty.$method() returned null', AdaptyErrorCode.emptyResult, null);
      }

      final decodedResult = json.decode(stringResult) as Map<String, dynamic>;
      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.$method(), Result: $decodedResult');

      if (decodedResult.containsKey(Argument.error)) {
        final adaptyErrorData = decodedResult[Argument.error];

        final adaptyError = AdaptyErrorJSONBuilder.fromJsonValue(adaptyErrorData);
        throw adaptyError;
      } else {
        final successData = decodedResult[Argument.success];
        final successObject = responseParser(successData);

        AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.$method(), Success Object: $successObject');

        return successObject;
      }
    } on AdaptyError catch (e) {
      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.$method() Error: $e');
      throw e;
    } catch (e) {
      final adaptyError = AdaptyError(
        'Internal plugin error in Adapty.$method()',
        AdaptyErrorCode.internalPluginError,
        e.toString(),
      );

      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.$method() Error: $adaptyError');
      throw adaptyError;
    }
  }

  Future<dynamic> _tryHandleIncomingMethodCall(MethodCall call) async {
    try {
      return await _handleIncomingMethodCall(call);
    } catch (e) {
      AdaptyLogger.write(AdaptyLogLevel.error, 'Error in Adapty._handleIncomingMethodCall: $e');
      return null;
    }
  }

  Future<dynamic> _handleIncomingMethodCall(MethodCall call) {
    final arguments = json.decode(call.arguments) as Map<String, dynamic>;

    AdaptyLogger.write(AdaptyLogLevel.verbose, 'handleIncomingCall ${call.method} Args: $arguments');

    AdaptyUIFlowView decodeView() {
      return AdaptyUIFlowViewJSONBuilder.fromJsonValue(arguments[Argument.view]);
    }

    AdaptyUIOnboardingView decodeOnboardingView() {
      return AdaptyUIOnboardingViewJSONBuilder.fromJsonValue(arguments[Argument.view]);
    }

    AdaptyPaywallProduct decodeProduct() {
      return AdaptyPaywallProductJSONBuilder.fromJsonValue(arguments[Argument.product]);
    }

    AdaptyPaywallProduct? decodeProductIfPresent() {
      return arguments[Argument.product] != null ? AdaptyPaywallProductJSONBuilder.fromJsonValue(arguments[Argument.product]) : null;
    }

    AdaptyProfile decodeProfile() {
      return AdaptyProfileJSONBuilder.fromJsonValue(arguments[Argument.profile]);
    }

    AdaptyPurchaseResult decodePurchaseResult() {
      return AdaptyPurchaseResultJSONBuilder.fromJsonValue(arguments[Argument.purchasedResult]);
    }

    AdaptyError decodeError() {
      return AdaptyErrorJSONBuilder.fromJsonValue(arguments[Argument.error]);
    }

    AdaptyError? decodeErrorIfPresent() {
      return arguments[Argument.error] != null ? AdaptyErrorJSONBuilder.fromJsonValue(arguments[Argument.error]) : null;
    }

    AdaptyUIOnboardingMeta decodeOnboardingMeta() {
      return AdaptyUIOnboardingMetaJSONBuilder.fromJsonValue(arguments[Argument.meta]);
    }

    switch (call.method) {
      case IncomingMethod.didLoadLatestProfile:
        _didUpdateProfileController.add(decodeProfile());
        return Future.value(null);
      case IncomingMethod.onInstallationDetailsSuccess:
        final details = AdaptyInstallationDetailsJSONBuilder.fromJsonValue(arguments[Argument.details]);
        _onUpdateInstallationDetailsSuccessController.add(details);
        return Future.value(null);
      case IncomingMethod.onInstallationDetailsFail:
        _onUpdateInstallationDetailsFailController.add(decodeError());
        return Future.value(null);
      case IncomingMethod.flowViewDidAppear:
        AdaptyUI()._eventsProxy.flowViewDidAppear(decodeView());
        return Future.value(null);
      case IncomingMethod.flowViewDidDisappear:
        AdaptyUI()._eventsProxy.flowViewDidDisappear(decodeView());
        return Future.value(null);
      case IncomingMethod.flowViewDidPerformAction:
        final action = AdaptyUIActionJSONBuilder.fromJsonValue(arguments[Argument.action]);
        AdaptyUI()._eventsProxy.flowViewDidPerformAction(decodeView(), action);
        return Future.value(null);
      case IncomingMethod.flowViewDidPerformSystemBackAction:
        AdaptyUI()._eventsProxy.flowViewDidPerformAction(
              decodeView(),
              const AndroidSystemBackAction(),
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidSelectProduct:
        final productId = arguments[Argument.productId] as String;
        AdaptyUI()._eventsProxy.flowViewDidSelectProduct(
              decodeView(),
              productId,
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidStartPurchase:
        AdaptyUI()._eventsProxy.flowViewDidStartPurchase(
              decodeView(),
              decodeProduct(),
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidFinishPurchase:
        AdaptyUI()._eventsProxy.flowViewDidFinishPurchase(
              decodeView(),
              decodeProduct(),
              decodePurchaseResult(),
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidFailPurchase:
        AdaptyUI()._eventsProxy.flowViewDidFailPurchase(
              decodeView(),
              decodeProduct(),
              decodeError(),
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidFinishRestore:
        AdaptyUI()._eventsProxy.flowViewDidFinishRestore(
              decodeView(),
              decodeProfile(),
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidStartRestore:
        AdaptyUI()._eventsProxy.flowViewDidStartRestore(decodeView());
        return Future.value(null);
      case IncomingMethod.flowViewDidFailRestore:
        AdaptyUI()._eventsProxy.flowViewDidFailRestore(
              decodeView(),
              decodeError(),
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidReceiveError:
        AdaptyUI()._eventsProxy.flowViewDidReceiveError(
              decodeView(),
              decodeError(),
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidFailLoadingProducts:
        AdaptyUI()._eventsProxy.flowViewDidFailLoadingProducts(
              decodeView(),
              decodeError(),
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidFinishWebPaymentNavigation:
        AdaptyUI()._eventsProxy.flowViewDidFinishWebPaymentNavigation(
              decodeView(),
              decodeProductIfPresent(),
              decodeErrorIfPresent(),
            );
        return Future.value(null);
      case IncomingMethod.flowViewDidAskPermission:
        final view = decodeView();
        final eventId = arguments[Argument.eventId] as String;
        final permission = AdaptyUIPermission(arguments[Argument.permission] as String);
        final customArgs = (arguments[Argument.customArgs] as Map?)?.cast<String, String>();
        final handler = AdaptyUI()._systemRequestsHandler;
        // No registered handler → no result. The native side keeps the request
        // pending until teardown, where it resolves as denied. We do not
        // fabricate a default answer here.
        if (handler == null) return Future.value(null);
        return Future(() async {
          final result = await handler.handlePermission(view, permission, customArgs);
          await _invokeMethod<void>(
            IncomingMethodResponse.flowViewDidAnswerPermission,
            (_) => null,
            {Argument.eventId: eventId, ...result.jsonValue},
          );
        });
      case IncomingMethod.flowViewDidRequestAppReview:
        final view = decodeView();
        final handler = AdaptyUI()._systemRequestsHandler;
        return Future(() async {
          // No registered handler → trigger the native review prompt by default.
          if (handler != null) {
            await handler.handleAppReviewRequest(view);
          } else {
            await AdaptyUI().requestAppReview();
          }
        });
      case IncomingMethod.flowViewDidReceiveAnalyticEvent:
        final name = arguments[Argument.name] as String;
        final params = (arguments[Argument.params] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        AdaptyUI()._eventsProxy.flowViewDidReceiveAnalyticEvent(decodeView(), name, params);
        return Future.value(null);
      case IncomingMethod.flowViewObserverDidInitiatePurchase:
        final eventId = arguments[Argument.eventId] as String;
        AdaptyUI()._observerModeResolver?.observerModeDidInitiatePurchase(
              decodeView(),
              decodeProduct(),
              () => _invokeMethod<void>(IncomingMethodResponse.observerPurchaseDidStart, (_) => null, {Argument.eventId: eventId}),
              () => _invokeMethod<void>(IncomingMethodResponse.observerPurchaseDidFinish, (_) => null, {Argument.eventId: eventId}),
            );
        return Future.value(null);
      case IncomingMethod.flowViewObserverDidInitiateRestore:
        final eventId = arguments[Argument.eventId] as String;
        AdaptyUI()._observerModeResolver?.observerModeDidInitiateRestore(
              decodeView(),
              () => _invokeMethod<void>(IncomingMethodResponse.observerRestoreDidStart, (_) => null, {Argument.eventId: eventId}),
              () => _invokeMethod<void>(IncomingMethodResponse.observerRestoreDidFinish, (_) => null, {Argument.eventId: eventId}),
            );
        return Future.value(null);
      case IncomingMethod.onboardingDidFinishLoading:
        AdaptyUI()._eventsProxy.onboardingViewDidFinishLoading(
              decodeOnboardingView(),
              decodeOnboardingMeta(),
            );
        return Future.value(null);
      case IncomingMethod.onboardingDidFailWithError:
        AdaptyUI()._eventsProxy.onboardingViewDidFailWithError(
              decodeOnboardingView(),
              decodeError(),
            );
        return Future.value(null);
      case IncomingMethod.onboardingOnAnalyticsActionEvent:
        AdaptyUI()._eventsProxy.onboardingViewOnAnalyticsEvent(
              decodeOnboardingView(),
              decodeOnboardingMeta(),
              AdaptyOnboardingsAnalyticsEventJSONBuilder.fromJsonValue(arguments[Argument.event]),
            );
        return Future.value(null);
      case IncomingMethod.onboardingOnCloseActionEvent:
        AdaptyUI()._eventsProxy.onboardingViewOnCloseAction(
              decodeOnboardingView(),
              decodeOnboardingMeta(),
              arguments[Argument.actionId] as String,
            );
        return Future.value(null);
      case IncomingMethod.onboardingOnCustomActionEvent:
        AdaptyUI()._eventsProxy.onboardingViewOnCustomAction(
              decodeOnboardingView(),
              decodeOnboardingMeta(),
              arguments[Argument.actionId] as String,
            );
        return Future.value(null);
      case IncomingMethod.onboardingOnPaywallActionEvent:
        AdaptyUI()._eventsProxy.onboardingViewOnPaywallAction(
              decodeOnboardingView(),
              decodeOnboardingMeta(),
              arguments[Argument.actionId] as String,
            );
        return Future.value(null);
      case IncomingMethod.onboardingOnStateUpdatedActionEvent:
        final action = arguments[Argument.action] as Map<String, dynamic>;

        AdaptyUI()._eventsProxy.onboardingViewOnStateUpdatedAction(
              decodeOnboardingView(),
              decodeOnboardingMeta(),
              action[Argument.elementId] as String,
              AdaptyOnboardingsStateUpdatedParamsJSONBuilder.fromJsonValue(action),
            );
        return Future.value(null);
      default:
        return Future.value(null);
    }
  }
}
