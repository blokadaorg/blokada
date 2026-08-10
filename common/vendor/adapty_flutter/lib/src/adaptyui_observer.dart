// ignore_for_file: deprecated_member_use_from_same_package
import 'adapty.dart';

import 'models/adapty_paywall_product.dart';
import 'models/adapty_profile.dart';
import 'models/adapty_error.dart';
import 'models/adaptyui/adaptyui_action.dart';
import 'models/adapty_purchase_result.dart';

import 'models/adaptyui/adaptyui_onboarding_meta.dart';
import 'models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import 'models/adaptyui/adaptyui_onboarding_view.dart';
import 'models/adaptyui/adaptyui_onboardings_analytics_event.dart';
import 'models/adaptyui/adaptyui_flow_view.dart';

abstract class AdaptyUIFlowsEventsObserver {
  /// This method is invoked when the flow view was presented.
  ///
  /// ```
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidAppear(AdaptyUIFlowView view) {}

  /// This method is invoked when the flow view was dismissed.
  ///
  /// ```
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidDisappear(AdaptyUIFlowView view) {}

  /// If the user presses the close button, this method will be invoked.
  ///
  /// The default implementation dismisses the view on [CloseAction] only:
  /// ```
  /// view.dismiss()
  /// ```
  /// [AndroidSystemBackAction] is delivered but not handled by default — if you
  /// want the Android system back button to close the flow, dismiss it yourself.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
    switch (action) {
      case const CloseAction():
        view.dismiss();
        break;
      case OpenUrlAction(:final url, :final openIn):
        AdaptyUI().openUrl(url, openIn: openIn);
        break;
      default:
        break;
    }
  }

  /// If product was selected for purchase (by user or by system), this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] which was selected.
  void flowViewDidSelectProduct(AdaptyUIFlowView view, String productId) {}

  /// If user initiates the purchase process, this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] of the purchase.
  void flowViewDidStartPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product) {}

  /// This method is invoked when a successful purchase is made.
  ///
  /// There is no default implementation; implement this method to decide what
  /// happens after a successful purchase (e.g. continue the flow or call `view.dismiss()`).
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] of the purchase.
  /// - [purchaseResult]: an [AdaptyPurchaseResult] object containing the information about successful purchase or it cancellation.
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  );

  /// This method is invoked when the purchase process fails.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] of the purchase.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidFailPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyError error) {}

  /// If user initiates the restore process, this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidStartRestore(AdaptyUIFlowView view) {}

  /// This method is invoked when a successful restore is made.
  ///
  /// Check if the [AdaptyProfile] object contains the desired access level, and if so, the controller can be dismissed.
  /// ```
  /// view.dismiss()
  /// ```
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [profile]: an [AdaptyProfile] object containing up to date information about the user.
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile);

  /// This method is invoked when the restore process fails.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) {}

  /// This method will be invoked in case of errors during the screen rendering process.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error);

  /// This method is invoked in case of errors during the products loading process.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidFailLoadingProducts(AdaptyUIFlowView view, AdaptyError error) {}

  /// This method is invoked when the web payment navigation is finished.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] object containing the information about the product.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {}

  /// This method is invoked when the flow view emits an analytic event.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [name]: the name of the analytic event.
  /// - [params]: a map containing the parameters of the analytic event.
  void flowViewDidReceiveAnalyticEvent(AdaptyUIFlowView view, String name, Map<String, dynamic> params) {}
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
abstract class AdaptyUIOnboardingsEventsObserver {
  void onboardingViewDidFinishLoading(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
  ) {}

  void onboardingViewDidFailWithError(
    AdaptyUIOnboardingView view,
    AdaptyError error,
  ) {}

  void onboardingViewOnCloseAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {}

  void onboardingViewOnPaywallAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {}

  void onboardingViewOnCustomAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {}

  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {}

  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) {}
}
