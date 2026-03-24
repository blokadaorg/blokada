# Home State

## Rules

### Rule: Home waiting state means protection is unresolved
Applies to: v6
Intent: Reserve the loading affordance for states still in flight.
Rule: The home screen shows progress/"please wait" semantics when app status is `unknown`, `initializing`, or `reconfiguring`, or while the stage is not ready. Once status resolves to active or inactive, the user should see actionable text instead.
Scope: Home status line, startup, reconfiguration.
Non-rules: Deactivated, paused, or expired-style states should not stay in generic waiting mode.
Verification: Check `status.isWorking()` and `_stage.isReady` handling on the home screen.

### Rule: Power button actionability depends on whether state is resolved
Applies to: v6
Intent: Prevent taps during unresolved transitions.
Rule: The power button is non-actionable while the app is in a working/loading state. Once resolved, tapping powers on directly for inactive/freemium states, and active paid states open the pause/turn-off action sheet instead of switching off immediately.
Scope: Home power button behavior.
Non-rules: Freemium active state should not expose the paid pause action sheet.
Verification: Check power-button tap handling for working, active paid, and freemium states.

### Rule: Timer is only relevant for paused state
Applies to: v6
Intent: Avoid showing countdown controls where no timer-backed pause exists.
Rule: The five-minute timer/countdown is meaningful only when a timed pause is active, which is represented `_appStart.pausedUntil`. In that case the timer arc and countdown replace the normal iconography.
Scope: Power button countdown, pause UX.
Non-rules: Standard deactivated or freemium states should not show the timer countdown.
Verification: Check `pausedUntil`, `pausedForAccurate`, and timer rendering.

## UI State Semantics

### Rule: Blue ring means active device-wide cloud-style protection
Applies to: v6
Intent: Preserve the main paid DNS/home visual meaning.
Rule: The main ring is blue when v6 is active without Plus VPN emphasis, which corresponds to active device-wide protection for `cloud` and also the base active layer beneath `plus`.
Scope: Home ring, activation feedback.
Non-rules: Blue alone does not prove the account is `cloud`; `plus` still includes the blue active base.
Verification: Check home animations for `activatedCloud` and `activatedPlus`.

### Rule: Orange ring means active Plus/VPN state
Applies to: v6
Intent: Distinguish the premium VPN-capable state from standard device-wide blocking.
Rule: The orange ring overlay is specific to `activatedPlus`. Behaviorally it means the app is in the Plus tier active state rather than plain cloud/DNS active state.
Scope: Home ring, Plus location controls.
Non-rules: Orange is not a generic "active" color for all accounts.
Verification: Check home ring animation for `activatedPlus`.

### Rule: Freemium uses its own active ring but still means Safari-only protection
Applies to: v6
Intent: Prevent agents from reading any active ring as full device-wide coverage.
Rule: Freemium home can render as active, but that active state means Safari-extension-based Essentials only. The home freemium copy must continue to say Safari is protected and prompt upgrade for system-wide coverage.
Scope: Freemium home card, power ring semantics.
Non-rules: Any active ring in freemium does not imply DNS/VPN/device-wide protection.
Verification: Check freemium home status copy and active-state derivation.
