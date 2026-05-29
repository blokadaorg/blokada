# Family rule editor — hybrid fix + tailored `+ New` flow

Status: draft for review · Tracker: blokadaorg/issue-tracker#292

## Problem

The schedule rule editor on Family kid devices has two real bugs and one product
gap that blocks first-time use:

- It seeds **Parent** as the default profile for a new rule, because
  `availableProfiles` is passed unfiltered and the editor selects `index 0`.
  Parent never makes sense on a kid device — rules are meant to carve stricter
  windows on the base profile, and Parent is laxer than any kid profile.
- The **`+ New`** chip is `onPressed: null` (`rule_editor_sheet.dart:200-203`).
  It exists today only so its label gets picked up by the i18n pipeline.
- There is **no path to configure blocklists** for a freshly-created profile
  from inside the rule editor. The existing `AddProfileSheet` Custom flow
  creates a profile with empty-template defaults and dumps the parent back into
  whatever screen they came from with no further guidance.

The flow is on the critical path for new users: every parent who taps "Add
rule" on a kid device hits the editor as their first encounter with the
feature.

## Scope

**In.**

- Chip-row filter (drop `parent` template, drop the device's own base profile).
- Smart default chip selection from the *filtered* list.
- Horizontal-scroll chip row with edge fade; `+ New` pinned at the end.
- `+ New` mini-flow: rename dialog → `FamilyFiltersSection` for the freshly
  created profile → back to the editor with the new chip auto-selected.
- Empty-state copy when no eligible chip exists.
- i18n keys for new copy.

**Out.**

- Curated School / Bedtime / Homework templates with differentiated default
  blocklists in `DefaultFilters.getTemplate`. Today they all inherit
  empty-template defaults; revisit only if user research warrants.
- Per-profile icon or emoji picker. All custom-template profiles continue to
  render with the amber `person_crop_circle`. No `JsonProfile` schema change.
- Editing existing profiles' blocklists from inside the rule editor. Chip tap
  stays "select", not "edit". Existing entry points for blocklist editing are
  unchanged.
- Orphan-handling when a rule's profile is deleted via the profile dialog's
  slide-to-delete. Existing schedule resolver behavior is preserved.

## UX

### Rule editor (normal case)

The editor keeps its current compact 1-sheet shape (profile chips → day preset
chips + 7 day toggles → time windows with the soft-cap hint). Two changes
inside the Profile section:

- Replace the `Wrap` widget with a horizontally-scrolling `Row` inside a
  `SingleChildScrollView`. Apply a trailing-side edge fade with `ShaderMask` so
  overflow is visually obvious. `+ New` is the last child and stays pinned at
  the end of the scroll.
- Filter `availableProfiles` before rendering chips:
  - drop any profile with `template == "parent"`
  - drop the device's own base profile (the one `ScheduleSection` shows in its
    Default row, sourced from `device.profile.profileId`)
- Seed `_profileId` from the **first eligible chip** in the filtered list,
  not the raw `availableProfiles.first`. After the auto-seed this is typically
  `School`.

### `+ New` mini-flow

1. Tap `+ New` in the chip row. The existing `showRenameDialog` opens with
   copy "Name this profile / You'll pick what it blocks on the next screen."
   Cancel returns to the editor with no profile created.
2. On Confirm, the editor host (`device_section.dart`) calls
   `ProfileActor.addProfile("", name)` to create the profile with
   empty-template defaults — the same path used by `_seedScheduleForNewDevice`
   for the auto-seeded School and Bedtime profiles — then `selectProfile`s it
   so the existing filter plumbing keys off it.
3. Push `FamilyFiltersSection(profileId: newId)` onto the rule editor sheet's
   inner Navigator. The page has a `‹ Back` affordance in the top bar and an
   explicit `Done` CTA at the bottom. `Done` pops back to the editor; the
   editor's `setState` rebuilds with refreshed `availableProfiles` from
   `ProfileActor`, and `_profileId` is set to the newly-created profile id.

### Empty state

When the filtered list is empty (legacy customer who never received the
auto-seed, or an account with only Parent + the device's base profile), the
chip row shows only `+ New`. A sublabel beneath the Profile section heading
reads "Tap + New to create a profile for this rule". The Save button is
disabled until `_profileId` resolves to a real profile via the mini-flow.

### Cancellation and abandonment

- Cancel in the rename dialog: no profile created. Editor returns to its
  previous state.
- Back-swipe or `‹ Back` from the blocklists step (without tapping Done): the
  newly-created profile remains in the user's profile list with the blocklist
  edits applied up to that point (the filter section auto-commits on each
  toggle today). On return to the editor, the new chip *is* auto-selected so
  the parent can finish the rule. They can also slide-to-delete the profile
  from the profile dialog if they want to abandon entirely.
- This matches the existing `AddProfileSheet` Custom path semantics. No new
  abandonment behavior is introduced.

## Component changes

### `rule_editor_sheet.dart`

- Add `onAddProfile: VoidCallback` constructor param. Inside `_buildProfileField`,
  replace the inert `ActionChip(onPressed: null)` with one wired to
  `widget.onAddProfile`.
- Replace the Profile-section `Wrap` with `SingleChildScrollView(scrollDirection:
  Axis.horizontal, child: Row(children: chips))` wrapped in a `ShaderMask` that
  fades the trailing edge.
- Compute `eligibleProfiles` once per build: `widget.availableProfiles.where((p)
  => p.template != "parent" && p.profileId != widget.deviceBaseProfileId)`. Add
  `deviceBaseProfileId` to the constructor signature.
- In `initState`, when `widget.initialRule == null`, set `_profileId` to
  `eligibleProfiles.firstOrNull?.profileId ?? ""`. When eligible list is empty,
  `_profileId` stays empty until the mini-flow returns.
- Render an empty-state sublabel beneath the Profile section heading when
  `eligibleProfiles.isEmpty`.
- Disable the Save button (existing `_save` path) when `_profileId` is empty.

### `device_section.dart`

- In `_openRuleEditor`, pass the device's base profile id as
  `deviceBaseProfileId` to the sheet. The chip filter still happens inside the
  sheet so widget tests can exercise it directly.
- Wire `onAddProfile` to a new private method `_onAddProfileFromRule(device)`
  that performs:
  1. `showRenameDialog(... title: "...profile new dialog title"...)`
  2. On confirm: `final p = await _profile.addProfile("", name, Markers.userTap)`
     and `await _profile.selectProfile(Markers.userTap, p)`.
  3. Push `FamilyFiltersSection(profileId: p.profileId, primary: true)` onto
     the rule-editor sheet's inner `Navigator`. Use a `MaterialPageRoute`. Wrap
     the page in a small host widget that exposes the `Done` CTA and pops with
     `result: p.profileId` so the rule editor can re-select it.
  4. Back in the editor, after `await Navigator.of(context).push(...)`, call
     `setState` to refresh the available-profile list and update `_profileId`
     with the returned id.

### Modal navigator considerations

The rule editor is opened via `_modalWidget.change(...)` and displayed inside
`BottomManagerSheet`. The editor's `Scaffold` runs inside that sheet's
Navigator. Pushing `FamilyFiltersSection` onto `Navigator.of(context)` from
inside the editor pushes onto the same sheet-local Navigator — the editor stays
mounted underneath, and `Navigator.pop` returns to it without dismissing the
modal. Verify during implementation that `_modalWidget.change` is not
re-issued on the inner push (no need to change modal state for an inner
navigation).

### i18n

Add new English keys; mirror to the iOS + Android SoT files via the existing
schedule i18n commit pattern.

- `family schedule rule editor profile new dialog title` — "Name this profile"
- `family schedule rule editor profile new dialog subtitle` — "You'll pick
  what it blocks on the next screen."
- `family schedule rule editor profile new blocklists done` — "Done"
- `family schedule rule editor profile empty subtitle` — "Tap + New to create
  a profile for this rule"

## Testing

### Widget tests (existing `rule_editor_sheet` test file extended)

- Chip row renders horizontally-scrolling content with `+ New` as the last
  child.
- Chip filter: when `availableProfiles` contains a `parent`-template profile,
  it is absent from the chip row. When it contains the device's base profile
  (via `deviceBaseProfileId`), that is also absent.
- Smart default: with `[Parent, School, Bedtime]` and base = Child (not in
  list), the seeded chip is School.
- Empty state: with `[Parent]` only and base = Child, chip row shows only
  `+ New`, the empty-state sublabel renders, Save is disabled.
- Tapping `+ New` invokes the supplied `onAddProfile` callback.

### Widget tests (`device_section`, new)

- `_onAddProfileFromRule` happy path with a fake `ProfileActor`: rename dialog
  confirmed → `addProfile("", name)` called → `selectProfile(p)` called →
  `FamilyFiltersSection` pushed → Done pops with `p.profileId` → editor's
  `_profileId` updated and chip rendered with selected state.
- Cancel-at-rename: no `addProfile` call, no navigator push.
- Back-from-filters: profile still exists in the actor; editor's `_profileId`
  updated to the new id (matches behavior on Done).

### E2E (Appium, optional but recommended)

On the FamilyMocked sim (`ACCOUNT_ID=lpuoibwchljd`), navigate to a kid device
→ Schedule section → Add rule. Assert:

- chip row excludes Parent and the device's own base profile
- the seeded chip is School
- `+ New` opens the rename dialog
- complete the flow and confirm the new chip is selected back in the editor

Capture screenshots into `automation/appium/output/` as a regression baseline.

## Open implementation edges

- `ProfileActor.selectProfile` mutates the global `UserFilterConfig` (per
  `actor.dart:72-83`). On the Family variant, the parent's own filter config
  is in a separate scope so this should be benign for the kid-profile case,
  but verify during implementation. If the side-effect leaks into the parent's
  own filter behavior, scope the selection to a managed-profile session that
  the editor restores on pop.
- `ShaderMask` edge-fade rendering on Android: verify with
  `RepaintBoundary` and on a real Android Family build before merge.

## Files touched

- `common/lib/src/app_variants/family/widget/device/rule_editor_sheet.dart`
- `common/lib/src/app_variants/family/widget/device/device_section.dart`
- One new small host widget for the blocklists step's `Done` CTA, likely
  alongside `rule_editor_sheet.dart` as `rule_editor_blocklists_page.dart`.
- `common/assets/translations/en.json` + iOS + Android SoT i18n files
  (mirroring the existing schedule i18n commit pattern).
- `common/test/app_variants/family/widget/device/rule_editor_sheet_test.dart`
  (exists; extend with chip-filter + smart-default + empty-state cases).
- `common/test/app_variants/family/widget/device/device_section_test.dart`
  (new; covers `_onAddProfileFromRule` happy path, rename cancel, back-from-filters).
