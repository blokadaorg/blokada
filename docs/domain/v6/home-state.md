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

### Rule: Protection confirmed fires once per user activation
Applies to: v6
Intent: Give activation feedback (pulse, haptic) only when the user's own switch-on succeeds.
Rule: `PowerActor.onProtectionConfirmed` fires on the first active status after the user switched protection on from the power button, including an activation that completes after DNS onboarding or the paywall within five minutes. The power button's look and tap action come from `powerButtonState` alone.
Scope: Power button, activation feedback.
Non-rules: App start, reconnects (reconfiguring back to active), switching freemium off, and protection coming up without a recent switch-on request do not fire it.
Verification: Check `common/lib/src/features/home/domain/power.dart` and its tests.

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

## Stats

### Rule: Home and Privacy Pulse read one set of stats
Applies to: v6
Intent: The same period never shows two different numbers.
Rule: `StatsController` owns fetching, refresh and the selected range for Home's 24h counter and Privacy Pulse. Pulse's 24h numbers are Home's stats, not a separate fetch. Each section is loading, ready, empty or error; a failed fetch shows an error with a retry, never "nothing to show".
Scope: Home counter, Privacy Pulse charts, toplists and recent activity.
Non-rules: Home refreshes every 30 s only while protection is on, the app is in the foreground and Home is not covered.
Verification: Check `common/lib/src/features/stats/domain/controller.dart` and its tests.

## Daily Home experiment

### Rule: The daily Home differs from today's only where the experiment means it to
Applies to: v6
Intent: A cohort split (#460) must measure the new Home, not unrelated differences between the arms.
Rule: The `home_variant` account attribute picks the Home: `daily` gets the daily Home, anything else (including no value) today's. Once an account is seen as `daily` in a session it stays daily, so a refresh without attributes cannot flip the layout. The daily Home changes only two states: protection on for an active account (status line, trial line during a store free trial, today's headline in place of the 24h counter, Plus bar) and a paid account that expired (end date, all-time blocked count, one resubscribe action on the `winback` placement). Accounts that never paid, freemium accounts and protection off render today's Home unchanged.
Scope: `HomeVariant`, `DailyHomeActor`, `DailyHomeActions`.
Non-rules: The trial line counts only an introductory `free_trial` from the store's access levels; web trials and promotional free periods show no line. The power button keeps opening the primary paywall in both arms; only the expired card opens `winback`.
Verification: Check `common/test/v6/widget/home/daily_actions_test.dart` and `common/test/app_variants/v6/module/home/home_test.dart`.

### Rule: The headline stays fixed for the day
Applies to: v6
Intent: Home shows something new each day without the headline changing every time the stats refresh.
Rule: Today's headline kind is picked once per local day and persisted (`home:headline_pick`); its numbers may update, the kind may not. A new day prefers a kind other than yesterday's. Candidates: the most blocked domain in 24 h (activity logging on), the busiest hour of the last 24, and the best Privacy Pulse weekly event (two weeks of data needed). With no candidate the 24h counter takes the slot.
Scope: `pickHomeHeadline`, Home headline card.
Non-rules: The Home pick never changes the weekly notification's event or its pending pick.
Verification: Check `pickHomeHeadline` tests.
