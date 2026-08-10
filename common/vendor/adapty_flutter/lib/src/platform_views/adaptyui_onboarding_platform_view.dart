// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:io';

import '../models/adapty_onboarding.dart';
import '../models/adapty_web_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert' show json;

import '../adapty.dart';
import '../adaptyui_observer.dart';
import '../constants/argument.dart';
import '../models/adapty_error.dart';
import '../models/adaptyui/adaptyui_onboarding_meta.dart';
import '../models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import '../models/adaptyui/adaptyui_onboarding_view.dart';
import '../models/adaptyui/adaptyui_onboardings_analytics_event.dart';

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyUIOnboardingPlatformView extends StatefulWidget {
  final AdaptyOnboarding onboarding;
  final AdaptyWebPresentation externalUrlsPresentation;

  final void Function(AdaptyUIOnboardingMeta)? onDidFinishLoading;
  final void Function(AdaptyError)? onDidFailWithError;
  final void Function(AdaptyUIOnboardingMeta, String)? onCloseAction; // meta, actionId
  final void Function(AdaptyUIOnboardingMeta, String)? onPaywallAction; // meta, actionId
  final void Function(AdaptyUIOnboardingMeta, String)? onCustomAction; // meta, actionId
  final void Function(AdaptyUIOnboardingMeta, String, AdaptyOnboardingsStateUpdatedParams)? onStateUpdatedAction; // meta, elementId, params
  final void Function(AdaptyUIOnboardingMeta, AdaptyOnboardingsAnalyticsEvent)? onAnalyticsEvent; // meta, event

  const AdaptyUIOnboardingPlatformView({
    super.key,
    required this.onboarding,
    this.externalUrlsPresentation = AdaptyWebPresentation.inAppBrowser,
    this.onDidFinishLoading,
    this.onDidFailWithError,
    this.onCloseAction,
    this.onPaywallAction,
    this.onCustomAction,
    this.onStateUpdatedAction,
    this.onAnalyticsEvent,
  });

  @override
  State<AdaptyUIOnboardingPlatformView> createState() => _AdaptyUIOnboardingPlatformViewState();
}

class _AdaptyUIOnboardingPlatformViewState extends State<AdaptyUIOnboardingPlatformView> implements AdaptyUIOnboardingsEventsObserver {
  String? _viewId;

  void _onPlatformViewCreated(int id) {
    final viewId = 'flutter_native_$id';
    _viewId = viewId;
    AdaptyUI().registerOnboardingEventsListener(this, viewId);
  }

  @override
  void dispose() {
    final viewId = _viewId;
    if (viewId != null) {
      AdaptyUI().unregisterOnboardingEventsListener(viewId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = {
      Argument.onboarding: widget.onboarding.jsonValue,
      Argument.externalUrlsPresentation: widget.externalUrlsPresentation.jsonValue,
    };

    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'adaptyui_onboarding_platform_view',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: json.encode(creationParams),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'adaptyui_onboarding_platform_view',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: json.encode(creationParams),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  void onboardingViewDidFailWithError(
    AdaptyUIOnboardingView view,
    AdaptyError error,
  ) {
    widget.onDidFailWithError?.call(error);
  }

  @override
  void onboardingViewDidFinishLoading(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
  ) {
    widget.onDidFinishLoading?.call(meta);
  }

  @override
  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) {
    widget.onAnalyticsEvent?.call(meta, event);
  }

  @override
  void onboardingViewOnCloseAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    widget.onCloseAction?.call(meta, actionId);
  }

  @override
  void onboardingViewOnCustomAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    widget.onCustomAction?.call(meta, actionId);
  }

  @override
  void onboardingViewOnPaywallAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    widget.onPaywallAction?.call(meta, actionId);
  }

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {
    widget.onStateUpdatedAction?.call(meta, elementId, params);
  }
}
