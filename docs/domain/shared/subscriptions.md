# Subscriptions And Entitlements

## Terms

- Account type: `libre`, `cloud`, `plus`, or `family`.
- Freemium: attribute-based entitlement overlay, not a separate account type.

## Rules

### Rule: Account type decides flavor compatibility
Applies to: shared
Intent: Prevent cross-flavor account acceptance.
Rule: Blokada 6 accepts `libre`, `cloud`, and `plus`. Blokada Family accepts `family` and `libre` only.
Scope: Login, restore, purchase result handling, entitlement checks.
Non-rules: A valid paid account in one flavor is not valid in the other flavor.
Verification: Check accepted account types per flavor.

### Rule: Freemium overlays an account instead of replacing its type
Applies to: shared
Intent: Keep rollout entitlements separate from paid tiers.
Rule: Freemium is stored as account attributes such as `freemium` and `freemium_youtube_until`; it can coexist with paid account types.
Scope: Account payloads and entitlement evaluation.
Non-rules: Freemium does not create a new account type and does not grant DNS/VPN just because the account is otherwise `libre`.
Verification: Check attribute presence independently from `type`.

### Rule: Active, inactive, expiring, and expired are distinct states
Applies to: shared
Intent: Avoid collapsing different user-visible states into one status.
Rule: `inactive` means the product is not currently in an active protected state; `expired` means a previously active subscription reached its end; `expiring` is the pre-expiry warning window.
Scope: Status text, paywall logic, expiry UI, extension state mapping.
Non-rules: `inactive` does not prove that the subscription expired.
Verification: Check current protection state separately from expiry timestamp.

### Rule: Entitlements grant different protection paths
Applies to: shared
Intent: Prevent reasonable-looking but wrong fallback behavior.
Rule: `plus` grants VPN-capable protection in Blokada 6 and still counts as DNS-capable for device-wide blocking. `cloud` grants DNS/device-wide protection only. `family` grants Family DNS/device-wide protection only in the Family app. Freemium `libre` on supported iOS flows grants Safari-extension-based Essentials only.
Scope: Paywall outcomes, home state derivation, onboarding choice, feature gating.
Non-rules: A non-`libre` account is not automatically VPN-capable in every flavor.
Verification: Compare app status resolution and onboarding behavior across account types.

### Rule: Expiry downgrade is one-way until a new upgrade
Applies to: shared
Intent: Keep expiry UX stable and avoid repeated downgrade handling.
Rule: When a paid account expires it falls back to `libre`; the "account expired" dialog is shown once for that expiry and is reset only by a later upgrade.
Scope: Account refresh, downgrade UX, plus cleanup.
Non-rules: Reopening the app alone should not reshow the same expiry dialog.
Verification: Check downgrade from paid to `libre`, then verify upgrade resets the expiry-seen state.

## Identity Notes

- Payment-provider identity should only be attached to an account after that account has been active before. This avoids creating duplicate purchase-provider profiles for brand-new users.
- Bootstrap identity is account-bound. A cached `deviceTag` or alias may be restored only when the current account ID matches; otherwise it must be discarded rather than reused across accounts.
