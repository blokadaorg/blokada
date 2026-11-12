import 'dart:io';

/// Environment variable the UI test suite (automation/appium) sets on every
/// app launch so one-time prompts don't cover the screens under test.
///
/// Only developer tooling can set a process environment variable (Appium/WDA
/// `mobile: launchApp`, `devicectl ... launch` with `DEVICECTL_CHILD_*`), and
/// those only launch debuggable builds; an App Store install started from the
/// home screen never has it.
const automationSkipPromptsEnv = 'BLOKADA_AUTOMATION_SKIP_PROMPTS';

/// True when the app was launched by the UI test suite asking to skip optional
/// one-time prompts (Safari video-ads onboarding, the automatic Rate us).
///
/// Why: on iOS, while those Flutter sheets are open the app exposes no
/// accessibility elements to XCUITest at all, so a fresh device (where they
/// have never been dismissed) blocks every smoke test.
bool get automationSkipsOptionalPrompts {
  try {
    return Platform.environment[automationSkipPromptsEnv] == '1';
  } catch (_) {
    return false;
  }
}
