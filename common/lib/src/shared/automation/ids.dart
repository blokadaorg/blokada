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

  /// Top-bar title of every WithTopBar screen/sub-page. Stable chrome marker
  /// so automation can tell "real screen with a title" apart from its body
  /// content and detect a screen that rendered with no body (blank/broken).
  static const screenTitle = 'automation.screen_title';

  /// Top-bar back control. The pushed routes (Settings/Advanced/Privacy Pulse
  /// and their sub-pages) are MaterialWithModalsPageRoute, so there is no iOS
  /// edge-swipe-back; this is the only reliable "pop one level" affordance and
  /// must stay resolvable for automation to explore beyond the first level.
  static const navBack = 'automation.nav_back';

  static const homeSettings = 'automation.home_settings';
  static const homePrivacyPulse = 'automation.home_privacy_pulse';
  static const homeAdvanced = 'automation.home_advanced';

  static const privacyPulseRangeDaily = 'automation.privacy_pulse_range_24h';
  static const privacyPulseRangeWeekly = 'automation.privacy_pulse_range_7d';

  static const settingsExceptions = 'automation.settings_exceptions';
  static const settingsRetention = 'automation.settings_retention';
  static const settingsWeeklyReport = 'automation.settings_weekly_report';
  static const settingsSupport = 'automation.settings_support';
  static const retentionToggle = 'automation.retention_toggle';

  // Exceptions sub-page controls (so exploration can switch tabs and open a
  // domain row to reach the domain-detail level instead of guessing labels).
  static const exceptionsTabBlocked = 'automation.exceptions_tab_blocked';
  static const exceptionsTabAllowed = 'automation.exceptions_tab_allowed';
  static const exceptionItem = 'automation.exception_item';

  // Add-exception dialog (settings top-bar "Add" -> domain field + Save) and the
  // per-row swipe delete, so automation can add, verify and remove a custom rule.
  static const exceptionAddButton = 'automation.exception_add_button';
  static const exceptionDomainInput = 'automation.exception_domain_input';
  static const exceptionSaveButton = 'automation.exception_save_button';
  static const exceptionDelete = 'automation.exception_delete';

  // Activity screen: the Privacy Pulse "Show All" entry, the search action + its
  // input field, and a list row. screenActivity already marks the screen body.
  static const recentActivityShowAll = 'automation.recent_activity_show_all';
  static const activitySearch = 'automation.activity_search';
  static const activitySearchField = 'automation.activity_search_field';
  static const activityItem = 'automation.activity_item';

  // Freemium upsell CTA (shared FreemiumScreen; e.g. the Advanced blocklists gate).
  static const freemiumCta = 'automation.freemium_cta';

  // Settings account header subscription-status label.
  static const settingsAccountStatus = 'automation.settings_account_status';

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
