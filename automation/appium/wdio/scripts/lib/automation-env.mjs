// Launch arguments the app under test gets on every iOS launch, so a fresh
// device behaves like one where the one-time prompts were already handled.
//
// Why: on a freshly erased iPhone the app shows the Safari "Want to block
// video ads?" sheet (after DNS is enabled) and the automatic Rate us. While
// either Flutter sheet is open the app exposes no accessibility elements to
// XCUITest at all, so the specs can neither see nor dismiss them.
//
// How: iOS puts `-key value` launch arguments into UserDefaults' argument
// domain, and the app keeps its non-secure persisted values as strings in
// UserDefaults.standard (ios/App/Binding/CoreBinding.swift), so these read as
// already set. No app code reads them specially; values follow the Dart
// persistence formats:
// - onboarding:safari     OnboardSafariValue, bool stored as "1"
// - rate:metadata:2025    RateMetadataValue, JSON with lastSeenRateScreen set
//   (wrapped in quotes so the argument domain's plist parser keeps it a string)
//
// Every launch path must carry them:
// - the session's own launch:   capabilities `appium:processArguments.args`
// - WDA launches:               `mobile: launchApp` { arguments }
// - devicectl launches:         after `--` (wdio.conf.ts, Makefile wake)
export const APP_AUTOMATION_ARGS = Object.freeze([
  "-onboarding:safari",
  "1",
  "-rate:metadata:2025",
  '"{\\"lastSeenRateScreen\\":\\"2025-01-01T00:00:00.000\\"}"'
]);
