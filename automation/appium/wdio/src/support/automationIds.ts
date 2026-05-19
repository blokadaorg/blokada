/**
 * Automation identifiers mirrored from `common/lib/src/shared/automation/ids.dart`.
 * Keep this list in sync with the Flutter constants so selectors stay stable
 * regardless of framework implementation details.
 */
export const AutomationIds = {
  screenHome: "automation.screen_home",
  screenActivity: "automation.screen_activity",
  screenPrivacyPulse: "automation.screen_privacy_pulse",
  screenAdvanced: "automation.screen_advanced",
  screenSettings: "automation.screen_settings",
  navHome: "automation.nav_home",
  navActivity: "automation.nav_activity",
  navAdvanced: "automation.nav_advanced",
  navSettings: "automation.nav_settings",
  navBack: "automation.nav_back",
  screenTitle: "automation.screen_title",
  exceptionsTabBlocked: "automation.exceptions_tab_blocked",
  exceptionsTabAllowed: "automation.exceptions_tab_allowed",
  exceptionItem: "automation.exception_item",
  retentionToggle: "automation.retention_toggle",
  homeSettings: "automation.home_settings",
  homePrivacyPulse: "automation.home_privacy_pulse",
  homeAdvanced: "automation.home_advanced",
  privacyPulseRangeDaily: "automation.privacy_pulse_range_24h",
  privacyPulseRangeWeekly: "automation.privacy_pulse_range_7d",
  settingsExceptions: "automation.settings_exceptions",
  settingsRetention: "automation.settings_retention",
  settingsWeeklyReport: "automation.settings_weekly_report",
  settingsSupport: "automation.settings_support",
  powerToggle: "automation.power_toggle",
  powerActionSheet: "automation.power_action_sheet",
  powerActionPauseFive: "automation.power_action_pause_five",
  powerActionTurnOff: "automation.power_action_turn_off",
  powerActionCancel: "automation.power_action_cancel",
  dnsOnboardingSheet: "automation.dns_onboard_sheet",
  dnsOpenSettings: "automation.dns_open_settings",
  onboardIntroSheet: "automation.onboard_intro_sheet",
  onboardContinue: "automation.onboard_continue",
  rateModal: "automation.rate_modal",
  rateDismiss: "automation.rate_dismiss"
} as const;

export type AutomationIdKey = keyof typeof AutomationIds;
