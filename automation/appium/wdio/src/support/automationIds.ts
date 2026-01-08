/**
 * Automation identifiers mirrored from `common/lib/src/shared/automation/ids.dart`.
 * Keep this list in sync with the Flutter constants so selectors stay stable
 * regardless of framework implementation details.
 */
export const AutomationIds = {
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
