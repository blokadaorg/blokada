/// Stable automation identifiers exposed via accessibility semantics.
///
/// Keep these identifiers framework-agnostic so they remain valid if a widget
/// moves between Flutter and native surfaces. The Appium test suite relies on
/// these constants for locating critical UI elements.
class AutomationIds {
  AutomationIds._();

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
