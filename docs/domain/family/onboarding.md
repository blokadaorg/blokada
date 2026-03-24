# Onboarding And Phases

## Rules

### Rule: Family uses phase-driven onboarding instead of v6-style power onboarding
Applies to: family
Intent: Keep Family guidance tied to parent/child setup state.
Rule: Family home state is driven by `FamilyPhase`, not the v6 app-status model. The important branches are fresh setup, missing DNS permissions, parent with devices, linked child states, and locked child-device states.
Scope: Family home screen, CTA selection, onboarding copy.
Non-rules: Family should not reuse v6 power-button or Safari-extension assumptions.
Verification: Check `FamilyPhase` mapping and `SmartOnboard` CTA logic.

### Rule: Family DNS onboarding is the protection prerequisite
Applies to: family
Intent: Make DNS permissions the main gating step for Family protection.
Rule: When Family requires permissions, the primary CTA opens the private DNS onboarding sheet. This applies to parent `noPerms`, linked child `linkedNoPerms`, and locked child `lockedNoPerms`.
Scope: Family onboarding CTA, protection readiness.
Non-rules: Family does not have a browser-extension fallback path.
Verification: Check `requiresPerms()` phases and `SmartOnboard._handleCtaTap`.

### Rule: Linked child devices keep child-managed continuity
Applies to: family
Intent: Prevent child devices from pretending they can locally resolve parent subscription health.
Rule: In linked mode, the child phase is derived from link token validity plus DNS permission state. A linked child with permissions but no valid token becomes `linkedExpired`; a linked child with permissions and valid token becomes `linkedActive`.
Scope: Linked child home state, CTA behavior.
Non-rules: `linkedExpired` does not mean the child should show the standalone parent activation flow.
Verification: Check `FamilyActor._updatePhaseNow` for linked-mode branches.

### Rule: Locked child-device states are distinct from linked child states
Applies to: family
Intent: Keep "this device is locked for child mode" separate from "this device is linked to a parent token".
Rule: `lockedActive`, `lockedNoPerms`, and `lockedNoAccount` are local locked-device states. They are not interchangeable with linked child phases even when they show similar permission or expiry problems.
Scope: Child mode, lock flow, CTA selection.
Non-rules: A locked device is not automatically linked, and a linked device is not automatically locally lock-managed.
Verification: Check `appLocked` branches vs linked-mode branches in Family phase derivation.

## UI State Semantics

### Rule: Family `starting` is the only generic waiting phase
Applies to: family
Intent: Keep loading semantics narrow and avoid vague waiting screens after resolution.
Rule: Family `starting` means the app is not yet ready to decide which setup state applies and should show loading/progress text. Once another phase is chosen, the screen should show concrete setup, permission, linked, or expired guidance.
Scope: Family home onboarding card.
Non-rules: `fresh`, `linkedExpired`, or `lockedNoAccount` should not look like endless loading.
Verification: Check `SmartOnboard` copy for `starting` vs resolved phases.
