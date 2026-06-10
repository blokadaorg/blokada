---
name: dep-validate
description: Use to validate risky dependency bumps end to end as a local or cloud-launched agent. Trigger when a Dependabot PR was handed to a human (major version or migration-flagged) or for the ecosystems Dependabot does not scan (iOS CocoaPods, the wireguard-apple / translate submodules). CI here is build + lint only, so this drives the runtime validation it cannot: unit tests, mocked simulator, then real-device paywall / protection smoke, and either proceeds on pure core refactors or escalates the behavioral judgement calls to a human.
---

# Dep Validate

Run the whole loop yourself, end to end — including the real-hardware stage. The human's job is to answer the judgement questions you escalate, not to run steps. This works the same whether you are local or a headless cloud-launched agent. The only step you cannot drive is the StoreKit sandbox purchase sheet (a system UI), so the device-connected host needs a sandbox Apple ID signed in. If no device is reachable at all, do not hand a human a runbook — escalate that the run must be repeated on a device-connected host (see §4).

CI in this repo (`.github/workflows/ci.yml`) is build + lint only, so a bump can go green yet break behavior at runtime. Adapty above all: the paywall, purchase, and restore are revenue-critical and only exercise on real hardware. Protection (DNS/VPN start), onboarding, and entitlements are the other surfaces that compile fine but can break in use.

This skill composes two leaf skills — do not reimplement them:
- `appium` — drive the live UI on a mocked simulator or a real device.
- `device-log` — pull the iOS share-log / crash report to inspect SDK init, payment, and tunnel errors.

## 1. Discover the queue

```bash
node automation/dep-validate/queue.mjs
```

Prints JSON: `queue` (open Dependabot PRs needing validation) and `advisories` (unscanned ecosystems). Each PR entry carries `reasons`, `majors`, `highRiskPackages`, and `surfaces` (e.g. `payment`, `platform-bridge`, `protection`, `messaging`, `build-system`) precomputed from the bump. Validate one PR per run; take the PR number as input for headless runs.

A queue entry means: the auto-merge workflow would hand it to a human (major bump, non-allowlist file, or github-actions), or it carries a high-risk package (Adapty, Firebase, WireGuard, pigeon, gradle/AGP) at any bump level. Advisories are version-drift notes only — there is no PR to check out, so you surface them, you do not run the loop on them.

## 2. The validation loop

Run fast to slow. Each stage gates the next: a hard failure stops the loop and you escalate with the evidence you captured. A stage that cannot run (no device, missing account id) is **blocked**, not passed — a blocked revenue/protection stage forces an escalation.

### Stage A — checkout + bootstrap

```bash
gh pr checkout <pr> --repo blokadaorg/blokada
git submodule update --init --recursive
# iOS bumps only (Podfile / Adapty / Firebase):
cd ios && bundle install && pod install && cd ..
```

Record the branch you came from so you can return to it when done.

**The dep-validate helpers may not exist on the checked-out PR branch.** A Dependabot branch created before this skill merged to `main` has no `automation/dep-validate/` scripts, so `node automation/dep-validate/queue.mjs` / `report.mjs` fail there. The helpers only need `gh` + the PR number, not the PR's own files — so run them from a known-good checkout, not the PR branch: discover the queue *before* Stage A checkout, and emit the report *after* you return to your own branch (or run the script via an absolute path / `git show <your-branch>:automation/dep-validate/report.mjs`). Once the skill is on `main` and the PR rebases, the scripts are present and this caveat is moot.

### Stage B — unit + static (fastest, always)

```bash
make test            # full Flutter suite incl. pigeon + build_runner codegen
fvm flutter analyze  # run from common/, or: make -C common analyze
```

When the bump touches Adapty, `common/pubspec.yaml`, or `ios/Podfile`, also run the fallback-consistency check the CI `check-adapty-fallback.yml` job runs:

```bash
node scripts/check-adapty-fallback-version.mjs
```

Gate: all green to continue. A pigeon or codegen-tool major most often surfaces here as regenerated bridge code that no longer compiles — that is a real failure, capture it.

**Tooling-only bumps don't touch the Flutter app**, so `make test` / `analyze` is the wrong gate for them. When the diff is confined to a dev-tooling manifest (e.g. `automation/appium/wdio/package*.json`, a CI-only action), validate the thing that bump can actually break instead:

```bash
cd automation/appium/wdio && npm ci          # installs under the bumped lockfile
npx tsc --noEmit -p tsconfig.json            # type-check the harness
npm run test:unit                            # headless .mjs unit tests
```

Judge by **delta, not absolute count**: a major like `typescript 5→6` may print pre-existing errors that have nothing to do with the bump. Re-run the identical check with the *old* version pinned (`npx -p typescript@<old> tsc --noEmit -p tsconfig.json`) on the same tree and diff the output — only *new* errors are the bump's fault. (The wdio harness runs no `tsc` in CI and executes specs via `ts-node`, so a type error there is informational, not a build break.) These bumps carry no app `surfaces`, so they stop at Stage B → classify; there is no Stage C/D.

### Stage C — mocked simulator smoke

Validates UI, onboarding, and settings that do not need real DNS/VPN or StoreKit. The `Mocked` / `FamilyMocked` schemes stub `NetworkExtension` and the store, so this stage cannot validate Adapty purchase or protection start — that is Stage D.

```bash
# needs a dev ACCOUNT_ID, or .env.local SIX_DEV_ACCOUNT_ID / FAMILY_DEV_ACCOUNT_ID.
# run-*-mocked is an ios/ target, so invoke it with -C ios from the repo root.
make -C ios run-six-mocked ACCOUNT_ID=<dev-account>      # or run-family-mocked
```

Then drive it with the `appium` skill in simulator mode (`IOS_USE_SIM=1`): start `make appium-explore-session IOS_USE_SIM=1`, send `ui.summary` / `ui.inspect`, walk onboarding and the screens the bump could touch. See `ios/SIMULATOR.md` for the sim flow. Gate: app launches and the covered flows show no regression.

### Stage D — real-device smoke (slowest, covers what mocks stub)

This is the gate for revenue/trust-critical bumps. Drive the physical device with the `appium` skill (physical mode needs elevated access — see its SKILL.md). A default `make appium-explore-session IOS_DEVICE_NAME="<device>"` already installs the current workspace build before driving it; use the install-only target below only when you want to install without launching a session:

```bash
make -C ios appium-install-six      # or appium-install-family (install-only)
```

You run this yourself via `appium` — it is not a human runbook. Exercise: paywall display, then purchase and restore (Adapty); and protection start (DNS/VPN). The one step you cannot drive is the StoreKit **sandbox purchase sheet** (a system UI), so the host needs a sandbox Apple ID signed in (Settings → App Store) for the purchase/restore leg.

Record Stage D as **per-check stages**, not one monolithic stage, so the report can tell a seam from a missing device. Name them `real-device:paywall`, `real-device:protection`, `real-device:purchase`, etc. Mark the ones you drove `pass`/`fail`. If you reached the paywall but the sandbox purchase sheet stopped you, mark `real-device:purchase` `blocked` while the others stay `pass` — `report.mjs` then escalates only that seam (not "re-run on a device"). Only when *no* device stage ran at all does it emit the re-run escalation.

Pull logs with `device-log` and scan for SDK-init / payment / tunnel errors:

```bash
node automation/device/log.mjs
node automation/device/log.mjs ARTIFACT=crash   # if the app terminated
```

Capture screenshots (`ui.screenshot`) of the paywall / purchase result as report artifacts. Treat one flaky device failure as flaky: re-run the stage once before calling it a real regression.

### Stage E — post-merge cross-check

After a merge, read the physical-device smoke the `appium-smoke.yml` workflow runs:

```bash
gh run list --workflow appium-smoke.yml --repo blokadaorg/blokada --limit 5
gh run view <run-id> --repo blokadaorg/blokada --log
```

Pass/fail is in the job log; failure artifacts (screenshots, XML) are under `automation/appium/output/` on the run. If post-merge smoke fails, recommend rollback in your report.

## 3. Classify: proceed vs escalate

You are deciding one thing: is this bump **pure internal/core refactoring** you can validate and proceed on, or a **behavioral change** that needs a human's judgement? Read three signals:

- **Package identity** — `queue.mjs` already mapped high-risk packages to `surfaces`. Adapty → payment, WireGuard → protection, Firebase → messaging, pigeon → platform-bridge, gradle/AGP → build-system. Any of these is behavioral until proven otherwise.
- **Changed files** — `offlistFiles` in the queue entry means the PR touches code beyond the dependency manifests; inspect that diff (`gh pr diff <pr>`), it is not a pure bump.
- **Release notes** — apply the same rule the auto-merge workflow uses: escalate on explicit `BREAKING CHANGE`, migration language ("must migrate", "action required" with steps), public API removal your code calls, or a StoreKit/entitlement/paywall-config delta. Do **not** escalate on bare "behavior change", internal-only changes, or deprecation without removal.

Decide:
- **Proceed** — Stages B–D green AND no behavioral signal on payment / entitlement / onboarding / protection AND no high-risk package surprise. Record the validated result; the bump can follow the normal merge path. Write the report (artifact only, no PR comment).
- **Escalate** — any behavioral change on those surfaces, StoreKit risk, a blocked revenue/protection stage, or a Stage D / post-merge smoke failure. Do not settle it in code. Surface the specific question with evidence.

## 4. Emit the decision

Build a JSON decision payload (schema in `automation/dep-validate/report.mjs`) and pipe it in. The report artifact is always written; the PR comment fires only on escalate.

```bash
echo "$payload" | node automation/dep-validate/report.mjs --comment
```

- Artifact: `automation/dep-validate/output/<pr>-<timestamp>.md` — full evidence (commands, per-stage pass/fail, log excerpts, screenshot paths, classification rationale).
- PR comment (escalate only): a compact version with the exact question, the release-note quote, and a proceed/hold/rollback recommendation. The helper upserts a single marked comment, so re-runs do not spam the PR.
- Stage D escalations are auto-derived from the `real-device:*` stages (see §2 naming) + `surfaces`; both phrasings are deliberately **not** a human step-by-step — the agent runs the loop:
  - **No device ran** (every `real-device:*` stage `blocked`/`skip`) → "real-hardware validation pending": **re-run this agent on a device-connected host**, with the `surfaces` still unvalidated.
  - **Seam only** (some `real-device:*` passed, but a `purchase`/`restore` one is `blocked`) → a focused "sandbox-sheet seam" note: confirm purchase/restore on the host or accept the residual risk. No re-run message.
  - If you drove Stage D fully (`pass`/`fail`), neither block appears.

Keep the public-repo comment free of any private issue-tracker detail. Reference the tracker as `#320` or a full URL, never with a closing keyword (`fixes`/`closes`), to avoid cross-repo auto-close.

## 5. Headless / cloud execution

- Fully non-interactive: take the PR number as input, never block on a prompt. Every judgement call goes to the PR comment + report, never an interactive question.
- Account seeding: Stage C needs `ACCOUNT_ID` or `.env.local` `SIX_DEV_ACCOUNT_ID` / `FAMILY_DEV_ACCOUNT_ID`. If absent, mark the stage `blocked` and escalate — do not hang.
- Device availability: Stage D assumes the connected device / self-hosted runner that `appium-smoke.yml` uses, and you run it there yourself. If no device is reachable, mark Stage D `blocked` — `report.mjs` then emits the device-gap escalation (§4): re-run this agent on a device-connected host. Do not turn that into a human step-by-step; the agent runs the loop. Never mark a revenue/protection bump validated off a mocked run alone.
- iOS device services (Stage C sim is exempt; Stage D and `device-log` are not) need elevated access from the sandbox — request it before the install / Appium / `devicectl` steps, same as the `appium` and `device-log` skills note.

## Gaps and limitations

- **iOS-first.** `device-log` and the real-device `appium` path are iOS only. On-device Android validation (`adb install`, `adb logcat` inspection) is a documented follow-up, not built yet — for an Android bump, run Stage B (the assemble below), then escalate the on-device check.
  - **Build an Android bump with `make build-android-six-debug`, not `make -C android apk-six-debug`.** The bare `apk-six-debug` target assumes the Flutter module AAR (`org.blokada.flutter.common:flutter_debug`) is already published to the local maven repo; on a fresh checkout it fails with `Could not find …:flutter_debug:1.0`. `make build-android-six-debug` runs `regen-android` first (pub get, pigeon/codegen, `lib-debug` → builds the AAR) and then the assemble. Use `apk-family-debug` analogously for the family flavor (Adapty is a `sixImplementation`, so `six` is the flavor that exercises payment).
- **For Android bumps the loop's job is usually diagnosis, not detection.** A pure build break is already caught by the repo's CI `android assemble` job, so the bump's PR is red before you start. Value-add here is the *why* and the *fix*, not "build failed". Two distinct failure modes, with different diagnoses — tell them apart before writing the escalation:
  - **Toolchain-floor coupling** (e.g. `#1078`: bumped androidx requiring a newer AGP / compileSdk than the repo pins). The fix is ordering: which toolchain bump (AGP `#1080`, gradle-wrapper `#1079`) or manual change (compileSdk raise — no Dependabot PR covers it) must land *first*. Diagnose by comparing the library's required AGP/compileSdk/minSdk floors against the repo's (`android/build.gradle` classpath, `android/app/build.gradle` `compileSdk`/`minSdkVersion`).
  - **Removed / renamed sub-artifact** (e.g. `#1081`: `firebase-bom` 34 deleted the `-ktx` modules, so `firebase-messaging-ktx` resolved an empty version → `Could not find …-ktx:.`). The repo's toolchain floors are *fine*; the bump dropped or renamed a coordinate the build still references. Diagnose by reading the bump's release notes for removed/renamed/merged artifacts, then grep whether the code actually consumes the removed surface (here `FcmService.kt` used only the main `com.google.firebase.messaging.*` API, no `.ktx` import) — that tells you whether the fix is a clean manifest rename or also needs source edits. The fix is a one-line manifest edit Dependabot can't make, so the bump can't merge as-is; recommend hold + the exact edit.
  - Either way: runtime-behavior validation (the part CI can't do) only starts once it compiles — which on Android means a real device, i.e. the stub above. So even a "fix is one line, behaviorally safe" call carries a residual on-device gap (e.g. FCM push actually arriving); name it.
- **Mocked schemes stub Adapty / DNS / VPN.** Never report those flows validated from a Stage C run alone; they require Stage D.
- **Advisories are not validated.** CocoaPods and submodule entries from `queue.mjs` are drift notes; bumping a submodule pointer or a pod is a manual change with no Dependabot PR to drive the loop. Latest-version lookup for pods is left to you (the lock only gives the current pin).
- **One physical device.** Stage D and `appium-smoke.yml` contend for the same device; serialize, do not run them at once.
- **Keep the queue logic in sync.** `automation/dep-validate/lib/queue.mjs` ports the allowlist + major-bump rules from `.github/workflows/dependabot-auto-merge.yml`. If that workflow's allowlist changes, mirror it here.
