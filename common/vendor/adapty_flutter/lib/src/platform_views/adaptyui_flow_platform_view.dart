import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert' show json;

import '../adapty.dart';
import '../adaptyui_observer.dart';
import '../constants/argument.dart';
import '../models/private/json_builder.dart';
import '../models/adapty_error.dart';
import '../models/adapty_flow.dart';
import '../models/adapty_paywall_product.dart';
import '../models/adapty_product_identifier.dart';
import '../models/adapty_profile.dart';
import '../models/adapty_purchase_parameters.dart';
import '../models/adapty_purchase_result.dart';
import '../models/adaptyui/adaptyui_action.dart';
import '../models/adaptyui/adaptyui_flow_view.dart';
import '../models/custom_assets/adaptyui_custom_assets.dart';

class AdaptyUIFlowPlatformView extends StatefulWidget {
  final AdaptyFlow flow;

  /// The identifier of the localization to render the flow with, e.g. `en`,
  /// `es`, `fr`.
  ///
  /// If `null`, the view is rendered in `en`, falling back to the flow's
  /// default localization when the flow has no `en`. Asking for a localization
  /// the flow does not have falls back to the flow default as well, without an
  /// error. Strings missing from the chosen localization are filled in from the
  /// default one.
  final String? locale;

  /// Android only. If `true`, the flow view applies the safe-area insets as
  /// paddings. Has no effect on iOS. Defaults to `false` for the embedded view,
  /// which is usually hosted inside a widget tree that already manages
  /// safe-area insets (e.g. a `SafeArea`), so native paddings would double up.
  final bool androidEnableSafeArea;

  final Map<String, String>? customTags;
  final Map<String, DateTime>? customTimers;
  final Map<String, AdaptyCustomAsset>? customAssets;
  final Map<AdaptyProductIdentifier, AdaptyPurchaseParameters>? productPurchaseParams;

  final void Function(AdaptyUIFlowView)? onDidAppear;
  final void Function(AdaptyUIFlowView)? onDidDisappear;
  final void Function(AdaptyUIFlowView, AdaptyUIAction)? onDidPerformAction;
  final void Function(AdaptyUIFlowView, String)? onDidSelectProduct;
  final void Function(AdaptyUIFlowView, AdaptyPaywallProduct)? onDidStartPurchase;
  final void Function(AdaptyUIFlowView, AdaptyPaywallProduct, AdaptyPurchaseResult)? onDidFinishPurchase;
  final void Function(AdaptyUIFlowView, AdaptyPaywallProduct, AdaptyError)? onDidFailPurchase;
  final void Function(AdaptyUIFlowView)? onDidStartRestore;
  final void Function(AdaptyUIFlowView, AdaptyProfile)? onDidFinishRestore;
  final void Function(AdaptyUIFlowView, AdaptyError)? onDidFailRestore;
  final void Function(AdaptyUIFlowView, AdaptyError)? onDidReceiveError;
  final void Function(AdaptyUIFlowView, AdaptyError)? onDidFailLoadingProducts;
  final void Function(AdaptyUIFlowView, AdaptyPaywallProduct?, AdaptyError?)? onDidFinishWebPaymentNavigation;
  final void Function(AdaptyUIFlowView, String, Map<String, dynamic>)? onDidReceiveAnalyticEvent;

  const AdaptyUIFlowPlatformView({
    super.key,
    required this.flow,
    this.locale,
    this.androidEnableSafeArea = false,
    this.customTags,
    this.customTimers,
    this.customAssets,
    this.productPurchaseParams,
    this.onDidAppear,
    this.onDidDisappear,
    this.onDidPerformAction,
    this.onDidSelectProduct,
    this.onDidStartPurchase,
    this.onDidFinishPurchase,
    this.onDidFailPurchase,
    this.onDidStartRestore,
    this.onDidFinishRestore,
    this.onDidFailRestore,
    this.onDidReceiveError,
    this.onDidFailLoadingProducts,
    this.onDidFinishWebPaymentNavigation,
    this.onDidReceiveAnalyticEvent,
  });

  @override
  State<AdaptyUIFlowPlatformView> createState() => _AdaptyUIFlowPlatformViewState();
}

class _AdaptyUIFlowPlatformViewState extends State<AdaptyUIFlowPlatformView> implements AdaptyUIFlowsEventsObserver {
  String? _viewId;

  void _onPlatformViewCreated(int id) {
    final viewId = 'flutter_native_$id';
    _viewId = viewId;
    AdaptyUI().registerFlowEventsListener(this, viewId);
  }

  @override
  void dispose() {
    final viewId = _viewId;
    if (viewId != null) {
      AdaptyUI().unregisterFlowEventsListener(viewId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = {
      Argument.flow: widget.flow.jsonValue,
      if (widget.locale != null) Argument.locale: widget.locale,
      Argument.enableSafeAreaPaddings: widget.androidEnableSafeArea,
      if (widget.customTags != null) Argument.customTags: widget.customTags,
      if (widget.customTimers != null)
        Argument.customTimers: widget.customTimers!.map((key, value) => MapEntry(
              key,
              value.toAdaptyValidString(),
            )),
      if (widget.customAssets != null)
        Argument.customAssets: widget.customAssets!.entries
            .map((entry) => {
                  Argument.id: entry.key,
                  ...entry.value.jsonValue,
                })
            .toList(),
      if (widget.productPurchaseParams != null)
        Argument.productPurchaseParameters: AdaptyProductIdentifier.convertProductPurchaseParamsToJson(
          widget.productPurchaseParams,
        ),
    };

    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'adaptyui_flow_platform_view',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: json.encode(creationParams),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'adaptyui_flow_platform_view',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: json.encode(creationParams),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => widget.onDidAppear?.call(view);

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) => widget.onDidDisappear?.call(view);

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => widget.onDidPerformAction?.call(view, action);

  @override
  void flowViewDidSelectProduct(AdaptyUIFlowView view, String productId) => widget.onDidSelectProduct?.call(view, productId);

  @override
  void flowViewDidStartPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product) => widget.onDidStartPurchase?.call(view, product);

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) =>
      widget.onDidFinishPurchase?.call(view, product, purchaseResult);

  @override
  void flowViewDidFailPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyError error) => widget.onDidFailPurchase?.call(view, product, error);

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) => widget.onDidStartRestore?.call(view);

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) => widget.onDidFinishRestore?.call(view, profile);

  @override
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) => widget.onDidFailRestore?.call(view, error);

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => widget.onDidReceiveError?.call(view, error);

  @override
  void flowViewDidFailLoadingProducts(AdaptyUIFlowView view, AdaptyError error) => widget.onDidFailLoadingProducts?.call(view, error);

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) =>
      widget.onDidFinishWebPaymentNavigation?.call(view, product, error);

  @override
  void flowViewDidReceiveAnalyticEvent(AdaptyUIFlowView view, String name, Map<String, dynamic> params) =>
      widget.onDidReceiveAnalyticEvent?.call(view, name, params);
}
