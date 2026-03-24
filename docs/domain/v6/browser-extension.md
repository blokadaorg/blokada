# Browser Extension

## Rules

### Rule: Safari extension is optional for paid v6 accounts
Applies to: v6
Intent: Keep paid protection primarily device-wide.
Rule: For active paid accounts, the Safari extension is an optional add-on, mainly for Safari-specific extras such as YouTube handling.
Scope: iOS v6 extension onboarding and status display.
Non-rules: Paid users do not need the extension for core device-wide protection.
Verification: Check paid account behavior with and without active extension.

### Rule: Safari extension is mandatory for freemium protection
Applies to: v6
Intent: Make freemium protection depend on Safari rather than device-wide DNS/VPN.
Rule: Freemium users only get blocking through the Safari extension. Basic freemium gives essentials; a valid `freemium_youtube_until` adds the temporary YouTube/cookie-popup trial.
Scope: iOS freemium activation, extension popup, onboarding.
Non-rules: Freemium does not unlock device-wide blocking.
Verification: Check freemium account with inactive extension vs active extension.

### Rule: Extension popup status separates inactive from expired
Applies to: v6
Intent: Prevent misleading UI in the Safari popup.
Rule: Popup `inactive` means app-side protection is not currently active, which can happen because the native app is paused or onboarding was not completed. Expired paid subscriptions are evaluated separately and may still resolve to freemium essentials or trial if freemium attributes are present.
Scope: Safari popup status text and styling.
Non-rules: `inactive` in the popup does not by itself mean "subscription expired".
Verification: Compare paused/unconfigured app state vs expired paid state with and without freemium attributes.

### Rule: Safari onboarding has optional and mandatory paths
Applies to: v6
Intent: Show extension onboarding only when it is materially needed.
Rule: The optional Safari YouTube onboarding is shown on iOS after DNS permissions are granted and only if the Safari onboarding has not been dismissed and the extension has not been seen recently. The mandatory Safari onboarding is shown after successful freemium activation when the extension is still not active.
Scope: iOS v6 onboarding.
Non-rules: Paid-account optional onboarding should not behave like a hard requirement.
Verification: Check paid iOS onboarding after DNS permission grant, then freemium purchase flow with inactive extension.

### Rule: Freemium activation is driven by recent extension ping, not by DNS state
Applies to: v6
Intent: Keep Essentials tied to the Safari extension instead of accidental DNS assumptions.
Rule: Freemium unpause/activation validates the recent Blockaweb ping. If the extension ping is valid and active, the app can enter freemium-active state; if not, the app stays inactive and redirects toward paywall/onboarding rather than DNS setup.
Scope: Freemium power toggle, app foreground sync, paywall close handling.
Non-rules: DNS permission or paid-account logic should not be reused for freemium activation.
Verification: Compare freemium unpause with active ping, stale ping, and missing ping.

## Edge Cases

- When the Safari extension becomes active for freemium for the first time, the app may auto-unpause to complete activation.
- That auto-unpause must not override an explicit user power-off after freemium was already enabled once.
