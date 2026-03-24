# Protection

## Terms

- Device-wide protection: Blokada-managed DNS/VPN state used outside Safari.
- Essentials: freemium Safari-extension-only protection on supported iOS flows.

## Rules

### Rule: Plus is the only VPN-capable v6 account
Applies to: v6
Intent: Keep VPN access tied to the premium tier.
Rule: Only `plus` accounts are VPN-capable. `cloud` uses DNS/device-wide protection without VPN, and freemium `libre` does not use VPN.
Scope: Entitlement checks, plus/VPN controls, onboarding, troubleshooting.
Non-rules: Any paid account is not automatically VPN-capable.
Verification: Check VPN toggling and status handling for `plus` vs `cloud`.

### Rule: Device-wide DNS protection requires paid v6 entitlement
Applies to: v6
Intent: Prevent freemium users from entering the wrong onboarding path.
Rule: Device-wide DNS protection is for `cloud` and `plus` in Blokada 6. Freemium/Essentials does not use DNS onboarding and does not configure the device DNS profile.
Scope: Power toggle, DNS onboarding, startup checks, permission prompts.
Non-rules: A `libre` account with freemium attributes is not DNS-eligible.
Verification: Check unpause flow for `cloud`/`plus` vs freemium `libre`.

### Rule: DNS onboarding belongs to paid device-wide activation
Applies to: v6
Intent: Show the DNS profile wizard only when it is actually required.
Rule: After successful paid purchase, v6 shows DNS onboarding if private DNS is still missing and the flow is not a restore. On later foreground checks, the app should compare the live DNS setting with the expected Blokada DNS and show the wizard only when the live setting is wrong.
Scope: iOS DNS onboarding, post-purchase flow, foreground relaunch verification.
Non-rules: Freemium activation and generic startup should not trigger DNS onboarding.
Verification: Compare paid first activation, paid restore, matching DNS foreground, and mismatched DNS foreground.

### Rule: Power-on fallback depends on entitlement
Applies to: v6
Intent: Keep the power button behavior aligned with what the account can really use.
Rule: Turning protection on does one of three things: `plus`/`cloud` require DNS readiness and enable device-wide protection, freemium validates Safari extension activity and activates Essentials, and true `libre` without freemium opens the paywall.
Scope: Home power toggle, app unpause, onboarding exceptions.
Non-rules: Missing DNS permissions for paid users are not equivalent to freemium extension inactivity.
Verification: Check `AppStartStore._unpauseApp` behavior by account state.

## Edge Cases

- Restore flows for paid subscriptions should not immediately force the post-purchase DNS onboarding sheet.
- A DNS mismatch on foreground should surface the wizard over the normal UI and must not be coupled to a blank startup shell.
