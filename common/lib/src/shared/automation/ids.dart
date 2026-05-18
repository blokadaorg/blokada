/// Stable automation identifiers exposed via accessibility semantics.
///
/// Keep these identifiers framework-agnostic so they remain valid if a widget
/// moves between Flutter and native surfaces. The Appium test suite relies on
/// these constants for locating critical UI elements.
class AutomationIds {
  AutomationIds._();

  static const screenHome = 'automation.screen_home';
  static const screenActivity = 'automation.screen_activity';
  static const screenPrivacyPulse = 'automation.screen_privacy_pulse';
  static const screenAdvanced = 'automation.screen_advanced';
  static const screenSettings = 'automation.screen_settings';

  static const navHome = 'automation.nav_home';
  static const navActivity = 'automation.nav_activity';
  static const navAdvanced = 'automation.nav_advanced';
  static const navSettings = 'automation.nav_settings';

  static const homeSettings = 'automation.home_settings';
  static const homePrivacyPulse = 'automation.home_privacy_pulse';
  static const homeAdvanced = 'automation.home_advanced';

  static const privacyPulseRangeDaily = 'automation.privacy_pulse_range_24h';
  static const privacyPulseRangeWeekly = 'automation.privacy_pulse_range_7d';

  static const settingsExceptions = 'automation.settings_exceptions';
  static const settingsRetention = 'automation.settings_retention';
  static const settingsWeeklyReport = 'automation.settings_weekly_report';
  static const settingsSupport = 'automation.settings_support';

  static const powerToggle = 'automation.power_toggle';
  static const powerActionSheet = 'automation.power_action_sheet';
  static const powerActionPauseFive = 'automation.power_action_pause_five';
  static const powerActionTurnOff = 'automation.power_action_turn_off';
  static const powerActionCancel = 'automation.power_action_cancel';

  static const dnsOnboardingSheet = 'automation.dns_onboard_sheet';
  static const dnsOpenSettings = 'automation.dns_open_settings';

  static const onboardIntroSheet = 'automation.onboard_intro_sheet';
  static const onboardContinue = 'automation.onboard_continue';

  static const rateModal = 'automation.rate_modal';
  static const rateDismiss = 'automation.rate_dismiss';
}
