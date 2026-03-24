# Startup

## Rules

### Rule: Foreground startup can be deferred for background launches
Applies to: shared
Intent: Keep background-triggered launches from booting the full foreground UI too early.
Rule: Background/bootstrap launches keep a transparent placeholder until the app is resumed and the foreground promotion finishes. Foreground launches render the normal app UI immediately.
Scope: Launch context, startup shell, notification/background-triggered app starts.
Non-rules: A background launch placeholder is not the same as protection being inactive.
Verification: Check `StartupPromotionGate` behavior for foreground vs background launch contexts.

### Rule: Startup loading and protection mismatch are separate concerns
Applies to: shared
Intent: Prevent DNS verification or onboarding problems from becoming blank-screen or stuck-startup bugs.
Rule: Foreground startup may continue into the regular UI while protection-specific checks run. DNS mismatch should show the DNS onboarding/wizard over the normal UI when needed, not replace the whole startup state.
Scope: iOS DNS verification, foreground relaunch, startup regressions.
Non-rules: A DNS mismatch does not mean the app failed to start.
Verification: Confirm foreground relaunch shows normal UI, then DNS onboarding only when the live DNS setting is wrong.

### Rule: "Please wait" is for unresolved protection state, not for every inactive state
Applies to: shared
Intent: Reserve loading language for states that are still being resolved.
Rule: Waiting/progress text belongs to startup and reconfiguration states such as initializing, reconfiguring, or Family `starting`. Once the app has resolved to inactive/paused/expired-style states, the UI should show a concrete action or status instead of generic waiting.
Scope: Home screen status text, onboarding transitions, Family startup state.
Non-rules: Inactive or missing-permission states should not look like endless loading.
Verification: Check home/status text for working states vs resolved inactive states.
