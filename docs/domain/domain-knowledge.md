# Domain Knowledge

Use these files as the compact product-behavior reference:

- `docs/domain/shared/subscriptions.md`
- `docs/domain/shared/startup.md`
- `docs/domain/v6/browser-extension.md`
- `docs/domain/v6/protection.md`
- `docs/domain/v6/home-state.md`
- `docs/domain/family/onboarding.md`
- `docs/domain/family/subscriptions.md`

## Canonical Rules

### Rule: Protection path depends on account type and flavor
Applies to: all
Rule: In Blokada 6, `plus` can use VPN and DNS, `cloud` can use DNS only, and freemium `libre` can only use the Safari extension. In Family, only `family` accounts are valid and protection is DNS-based.

### Rule: Freemium is an entitlement overlay, not a subscription type
Applies to: shared
Rule: Freemium is carried in account attributes on an otherwise `libre` account. It enables Safari-only Essentials behavior on supported iOS flows and must not be treated as cloud/DNS/VPN entitlement.

### Rule: Startup readiness and protection readiness are separate
Applies to: shared
Rule: The app may be foreground-visible before all foreground-only checks complete. DNS mismatch or onboarding must not be represented as a global startup failure or blank shell.

### Rule: Inactive, paused, and expired are distinct
Applies to: all
Rule: `inactive` means protection is not currently usable, `paused` means the user or timer turned it off temporarily, and `expired` means the subscription ended. Do not infer one from another.

### Rule: Flavor compatibility is strict
Applies to: shared
Rule: Blokada 6 accepts `libre`, `cloud`, and `plus`. Blokada Family accepts `family` only.
