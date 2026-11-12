// Environment the app under test is launched with on iOS. The app reads it
// (common/lib/src/shared/automation/flags.dart) to skip optional one-time
// prompts: the Safari video-ads onboarding sheet and the automatic Rate us.
// While those Flutter sheets are open the app exposes no accessibility
// elements to XCUITest at all, so on a fresh device they block every spec.
//
// Every launch path must carry it:
// - the session's own launch:   capabilities `appium:processArguments.env`
// - WDA launches:               `mobile: launchApp` { environment }
// - devicectl launches:         DEVICECTL_CHILD_<name> in the caller's env
export const APP_AUTOMATION_ENV = Object.freeze({
  BLOKADA_AUTOMATION_SKIP_PROMPTS: "1"
});

/** Export DEVICECTL_CHILD_* so every `devicectl ... launch` passes the env on. */
export function exportDevicectlChildEnv(env = process.env) {
  for (const [key, value] of Object.entries(APP_AUTOMATION_ENV)) {
    env[`DEVICECTL_CHILD_${key}`] = value;
  }
}
