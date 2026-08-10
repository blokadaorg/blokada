class Method {
  static const String activate = 'activate';
  static const String setLogLevel = 'set_log_level';
  static const String getProfile = 'get_profile';
  static const String updateProfile = 'update_profile';
  static const String identify = 'identify';

  static const String getFlow = 'get_flow';
  static const String getFlowForDefaultAudience = 'get_flow_for_default_audience';
  static const String getPaywallProducts = 'get_paywall_products';

  static const String getOnboarding = 'get_onboarding';
  static const String getOnboardingForDefaultAudience = 'get_onboarding_for_default_audience';

  static const String makePurchase = 'make_purchase';
  static const String restorePurchases = 'restore_purchases';
  static const String updateAttribution = 'update_attribution_data';
  static const String logShowFlow = 'log_show_flow';
  static const String setFallback = 'set_fallback';

  static const String logout = 'logout';
  static const String presentCodeRedemptionSheet = 'present_code_redemption_sheet';
  static const String isActivated = 'is_activated';
  static const String reportTransaction = 'report_transaction';

  static const String setIntegrationIdentifiers = 'set_integration_identifiers';
  static const String updateCollectingRefundDataConsent = 'update_collecting_refund_data_consent';
  static const String updateRefundPreference = 'update_refund_preference';

  static const String createWebPaywallUrl = 'create_web_paywall_url';
  static const String openWebPaywall = 'open_web_paywall';

  static const String getCurrentInstallationStatus = 'get_current_installation_status';

  static const String createFlowView = 'adapty_ui_create_flow_view';
  static const String presentFlowView = 'adapty_ui_present_flow_view';
  static const String dismissFlowView = 'adapty_ui_dismiss_flow_view';

  static const String createOnboardingView = 'adapty_ui_create_onboarding_view';
  static const String presentOnboardingView = 'adapty_ui_present_onboarding_view';
  static const String dismissOnboardingView = 'adapty_ui_dismiss_onboarding_view';

  static const String showDialog = 'adapty_ui_show_dialog';
  static const String openUrl = 'adapty_ui_open_url';
  static const String requestAppReview = 'adapty_ui_request_app_review';
}

class IncomingMethod {
  static const String flowViewDidAppear = 'flow_view_did_appear';
  static const String flowViewDidDisappear = 'flow_view_did_disappear';
  static const String flowViewDidPerformAction = 'flow_view_did_perform_action';
  static const String flowViewDidPerformSystemBackAction = 'paywall_view_did_perform_system_back_action';
  static const String flowViewDidSelectProduct = 'flow_view_did_select_product';
  static const String flowViewDidStartPurchase = 'flow_view_did_start_purchase';
  static const String flowViewDidFinishPurchase = 'flow_view_did_finish_purchase';
  static const String flowViewDidFailPurchase = 'flow_view_did_fail_purchase';
  static const String flowViewDidStartRestore = 'flow_view_did_start_restore';
  static const String flowViewDidFinishRestore = 'flow_view_did_finish_restore';
  static const String flowViewDidFailRestore = 'flow_view_did_fail_restore';
  static const String flowViewDidReceiveError = 'flow_view_did_receive_error';
  static const String flowViewDidFailLoadingProducts = 'flow_view_did_fail_loading_products';
  static const String flowViewDidFinishWebPaymentNavigation = 'flow_view_did_finish_web_payment_navigation';

  static const String flowViewDidAskPermission = 'flow_view_did_ask_permission'; // flow_view_did_answer_permission + requestId
  static const String flowViewDidRequestAppReview = 'flow_view_did_request_app_review';
  static const String flowViewDidReceiveAnalyticEvent = 'flow_view_did_receive_analytic_event';
  static const String flowViewObserverDidInitiatePurchase = 'flow_view_observer_did_initiate_purchase';
  static const String flowViewObserverDidInitiateRestore = 'flow_view_observer_did_initiate_restore';

  static const String onboardingDidFinishLoading = 'onboarding_did_finish_loading';
  static const String onboardingDidFailWithError = 'onboarding_did_fail_with_error';
  static const String onboardingOnAnalyticsActionEvent = 'onboarding_on_analytics_action';
  static const String onboardingOnCloseActionEvent = 'onboarding_on_close_action';
  static const String onboardingOnCustomActionEvent = 'onboarding_on_custom_action';
  static const String onboardingOnPaywallActionEvent = 'onboarding_on_paywall_action';
  static const String onboardingOnStateUpdatedActionEvent = 'onboarding_on_state_updated_action';

  static const String didLoadLatestProfile = 'did_load_latest_profile';
  static const String onInstallationDetailsSuccess = 'on_installation_details_success';
  static const String onInstallationDetailsFail = 'on_installation_details_fail';
}

class IncomingMethodResponse {
  static const String flowViewDidAnswerPermission = 'flow_view_did_answer_permission';

  static const String observerPurchaseDidStart = 'observer_purchase_did_start';
  static const String observerPurchaseDidFinish = 'observer_purchase_did_finish';
  static const String observerRestoreDidStart = 'observer_restore_did_start';
  static const String observerRestoreDidFinish = 'observer_restore_did_finish';
}
