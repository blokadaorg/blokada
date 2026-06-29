# Appium WebdriverIO Harness

This folder contains the WebdriverIO + TypeScript suite that drives Appium
against the Blokada 6 iOS app on physical devices.

## One-Time Device & WebDriverAgent Setup

1. **Enable UI testing on the device**  
   Settings ▸ Privacy & Security ▸ Developer Mode ▸ turn on “UI Testing”.
2. **Open the bundled WebDriverAgent project**  
   ```bash
   cd automation/appium/wdio
   npm install
   APPIUM_HOME=../.appium npx appium driver install xcuitest
   APPIUM_HOME=../.appium npx appium driver run xcuitest open-wda
   ```
3. **Configure signing in Xcode**  
   - Select the `WebDriverAgentRunner` scheme.  
   - Choose your physical device (for example, your connected iPhone).  
   - In Signing & Capabilities set *Development Team* to your local Apple Developer team.
4. **Build/run once from Xcode**  
5. **Disable Auto-Lock on the device — REQUIRED**  
   Settings ▸ Display & Brightness ▸ Auto-Lock ▸ **Never**, and keep the
   device unlocked and on power.  
   If the iPhone sleeps/locks during a run, WebDriverAgent returns black
   screenshots and an empty/SpringBoard accessibility tree, so element
   lookups fail intermittently — manifesting as flaky
   `element ("~automation.power_toggle") still not existing` /
   `Failed to find General / Allmänt in Settings` failures that pass on
   re-run. This was the dominant cause of `appium-smoke` flakiness; it is
   a runner/device-configuration requirement, not a code issue. CI
   self-hosted-runner devices must have Auto-Lock set to Never.

After this, Appium can build WDA on demand using the same signing profile.

## Host Mac: Full Disk Access for `/var/db/lockdown/`

Appium's XCUITest driver reads the iPhone pair record from
`/var/db/lockdown/<UDID>.plist`. On macOS Ventura and newer that path is a
TCC-protected data vault, so the process running Appium must be granted **Full
Disk Access** or it will fail at session start with:

```
WebDriverError: Could not find a pair record for device '<UDID>'.
Please first pair with the device …
```

Even if `idevicepair pair` reports `SUCCESS` and Xcode shows the device as
paired, Appium still cannot read the file without FDA.

Setup on every host that runs the suite (especially CI Macs):

1. *System Settings ▸ Privacy & Security ▸ Full Disk Access* → add and enable
   the terminal app the suite is launched from (Terminal.app, iTerm2, Ghostty,
   VS Code, …). Each terminal is a separate entry — only the one you actually
   use matters.
2. If the suite is launched by a launchd-managed CI agent (GitHub Actions
   self-hosted runner, Jenkins, Buildkite, …), grant FDA to the agent binary
   itself instead — child processes inherit FDA from the parent, not from your
   interactive Terminal. Restart the agent after granting (`launchctl
   kickstart -k …` or logout/login).
3. If the host is reached over SSH, grant FDA to
   `/usr/libexec/sshd-keygen-wrapper` (use **Cmd-Shift-G** in the file picker
   to type the path) and reconnect. Screen Sharing sessions inherit FDA from
   the logged-in user's Terminal as expected and need no extra step.

Verification — from the same shell that will run `make appium-test`:

```sh
ls -la /var/db/lockdown/<UDID>.plist
```

Must succeed **without** `sudo`. (`sudo` swaps the responsible binary and
breaks TCC, so a working setup can still show "Operation not permitted" under
sudo — ignore that, it doesn't matter for Appium.) Note that `ls` on the
directory itself may still be denied even when FDA is correctly applied;
Appium looks the file up by UDID path, not by directory enumeration, so
reading the specific `.plist` is the only check that matters.

## Static Smoke Tests

```bash
make appium-test
```

Optional overrides:

- `make appium-test IOS_DEVICE_NAME="<device-name>"` – pick a device by name (script matches the first connected device whose name contains the value).
- `make appium-test IOS_UDID=<udid>` – skip the selector entirely and target a specific UDID.
- `make appium-test APP_FLAVOR=family` – build, install, and run the Blokada Family flavor instead of Blokada 6.
- `APP_BUNDLE_ID=…` – run against a different bundle id. If it does not match the selected flavor, set `APP_FLAVOR` explicitly so the install target stays correct.
- `SHOW_XCODE_LOG=0` – suppress verbose xcodebuild output.
- `IOS_AUTO_SELECT_FIRST=1` – skip interactivity and use the first paired physical device (enabled automatically in CI).

The target now performs the full device reset cycle for the selected flavor:

1. Auto-detects or resolves the target device (`IOS_UDID`) via `scripts/select-device.mjs` (interactive only when multiple devices are attached).
2. Builds the latest matching Appium install target (`ios/appium-install-six` or `ios/appium-install-family`), removes existing installs, and deploys the fresh `.app` via `devicectl`.
3. Launches the WebdriverIO smoke suite.

Artifacts are saved in `automation/appium/output/`:

- `wdio-launch-foreground.png` – app state before tapping.  
- `wdio-after-power.png` – app state after the interaction.  
- `wdio-launch-foreground.xml` – raw UI hierarchy for selector debugging.
- `*.log` – captured syslog excerpts when a test fails, alongside failure-specific screenshots and XML dumps.

Local harness-only tests:

- `make -C automation/appium test` – run the Appium harness unit tests plus the shared device-log tests without touching a real device.

Reusable flows and helpers live under `automation/appium/wdio/src/flows/` and `automation/appium/wdio/src/support/`. Specs in `src/specs/smoke/` compose these flows to exercise end-to-end journeys.

## AI Explorer

```bash
make appium-test
make appium-ai-explore APP_INSTALL=0
```

The AI explorer is intended to run after the static smoke test. The smoke test
builds, installs, and completes the DNS onboarding flow; the AI pass then
attaches to that already-onboarded app state and explores the accessible UI
without reinstalling by default.

Optional overrides:

- `AI_EXPLORER_BASE_URL=http://192.168.1.11:1234/v1` – OpenAI-compatible LM Studio endpoint (default).
- `AI_EXPLORER_MODEL=nvidia/nemotron-3-nano-4b` – default local model verified with LM Studio.
- `AI_EXPLORER_API_KEY=...` – optional bearer token for OpenAI-compatible servers that require one.
- `AI_EXPLORER_TIMEOUT_MS=720000` – wall-clock budget, default 12 minutes.
- `AI_EXPLORER_MAX_TOKENS=2500` – completion-token budget per model decision (default 2500, max 8000). Reasoning models (e.g. nemotron-nano) spend most of this on hidden chain-of-thought before emitting the JSON action, so it must stay well above the model's reasoning length or every decision fails with empty content.
- `AI_EXPLORER_STEP_LIMIT=36` – maximum model-planned actions.
- `AI_EXPLORER_FAKE_MODEL=1` – deterministic local harness mode for tests and debugging.
- `APP_INSTALL=1` – manually rebuild/reinstall before exploration; CI should leave this unset or `0` so it reuses the post-smoke onboarding state.

The model never controls Appium directly. It proposes one JSON action at a
time, and the local runner allows only safe JSONL explorer commands. Purchases,
subscription changes, sign-out, account deletion, external browser/mail flows,
and destructive Settings changes are denied before they reach the device.

Before handing control to the model, the runner performs a codebase-derived
mission warmup across the main V6 surfaces: Home, Privacy Pulse, Advanced, and
Settings. The warmup uses stable automation identifiers where available, scrolls
each reached screen, returns to Home, and records mission coverage in the
report. The warmup is capped at ~15% of the wall-clock budget so the model
still gets time to drive even if warmup navigation is slow. The model receives that coverage state, known failed
selectors, and the known surface checklist so it can spend its remaining budget
on unvisited areas instead of repeating the same tab or stale selector.

If the model returns no usable decision, the runner runs a deterministic
fallback probe and keeps going; only several consecutive failed decisions end
the run early, so one flaky response no longer aborts the whole exploration.

Artifacts are saved in `automation/appium/output/`:

- `ai-explorer-report.md` – reviewer-facing summary.
- `ai-explorer-report.json` – structured result with findings and recent steps.
- any screenshots/XML captured by the underlying explorer commands.

## Machine Session

```bash
make appium-explore-session
```

Optional overrides:

- `make appium-explore-session IOS_DEVICE_NAME="<device-name>"` – target a specific connected device.
- `make appium-explore-session IOS_UDID=<udid>` – force a specific device UDID.
- `make appium-explore-session APP_FLAVOR=family` – start the session with Blokada Family as the primary app instead of Blokada 6.
- `make appium-explore-session APP_INSTALL=0` – skip reinstalling the app before connecting. Use this only when you already installed the current workspace build and are intentionally reusing it.
- `make appium-explore-session IOS_AUTO_SELECT_FIRST=0` – re-enable the interactive selector instead of auto-picking the first connected physical device.
- `make appium-explore-session APP_BUNDLE_ID=…` – override the primary bundle id. If it is not the normal bundle for the selected flavor, set `APP_FLAVOR` explicitly as well.
- `make appium-explore-session SHOW_XCODE_LOG=0` – keep the app install path terse and only print the full Xcode build log on failure; also disables verbose WebDriverAgent logs.

Default review behavior is to auto-pick the first connected physical device and install the current workspace build before starting the interactive session. This is preferred for startup, notification, cold-start, and recent-diff validation so the app on device matches the code under review.

The repo-local Appium runtime patches WebDriverAgent startup so it preserves the device's current Auto-Correction and Predictive settings. The tests themselves must not navigate Settings to inspect or change those preferences.
On real devices the harness also prefers reusing an existing WebDriverAgent instead of force-restarting it on every run. Normal cleanup ends the active session so `Automation Running` disappears, but leaves reusable WDA state alone to reduce repeated PIN prompts. Use `APPIUM_WDA_HARD_RESET=1` only as a recovery path when the device-side automation state is stuck.
If you are not about to continue testing, always shut the session down rather than leaving the phone idle in automation mode. Reuse is for consecutive runs, not for leaving a personal device with the `Automation Running` banner visible.

Before a long interactive session, prepare the device manually:

- set Auto-Lock to `Never` or the longest available value
- keep the device unlocked before launching the session

The session host opens one long-lived Appium/WebDriver session and communicates over newline-delimited JSON on stdin/stdout. Requests are JSON objects:

```json
{"id":"1","command":"session.status","args":{}}
{"id":"2","command":"app.activate","args":{"target":"settings"}}
{"id":"3","command":"ui.summary","args":{}}
{"id":"4","command":"app.activate","args":{"target":"six"}}
{"id":"5","command":"ui.tap","args":{"selector":"~Privacy Pulse"}}
{"id":"6","command":"session.shutdown","args":{}}
```

Responses are also JSON objects. Each request emits:

- an `ack`
- a `result`
- a terminal `done`

or a terminal `error`

Example:

```bash
cd automation/appium/wdio
node scripts/explore.mjs --jsonl
```

Supported commands:

- `session.status`
- `session.shutdown`
- `app.targets`
- `app.launch`
- `app.activate`
- `app.terminate`
- `app.state`
- `ui.summary`
- `ui.inspect`
- `ui.tree`
- `ui.labels`
- `ui.read`
- `ui.tap`
- `ui.type`
- `ui.focusSearch`
- `ui.search`
- `ui.back`
- `ui.swipe`
- `ui.scroll`
- `ui.wait`
- `ui.exists`
- `ui.attr`
- `ui.source`
- `ui.screenshot`

Default machine workflow:

1. Start from a freshly installed workspace build unless you are deliberately reusing a known-good install.
2. Use `session.status` to confirm the session is alive.
3. Use `app.targets` if you need the built-in targets for `six`, `family`, and `settings`.
4. Switch apps with `app.activate`, for example `{"id":"2","command":"app.activate","args":{"target":"family"}}` or `{"id":"3","command":"app.activate","args":{"target":"settings"}}`.
5. Use `ui.summary` as the fast default inspection command while navigating the current foreground app. It reports the verified foreground target and active-app metadata rather than trusting `queryAppState` alone.
6. Use `ui.inspect` when you need bounded structure details. By default it includes labels, a tree summary, and a structured visible-element list.
7. Use `ui.read` for normalized element state reads, especially switches and other controls with `value`-style state.
8. Use `ui.focusSearch`, `ui.search`, `ui.back`, `ui.swipe`, and `ui.scroll` for dynamic exploration in Settings or either Blokada app without writing a temporary spec.
9. Use `ui.screenshot` or `ui.source` only when you need visual or raw-hierarchy artifacts.
10. Always finish with `session.shutdown` so the device exits automation mode cleanly without forcing a full WDA reset.
11. If you are done testing for now, do not keep the session open just to preserve reuse. Start a new session later instead of leaving the device showing `Automation Running`.

`app.launch`, `app.activate`, `app.state`, and `app.terminate` accept either:

- `args.target` for built-in targets `six`, `family`, or `settings`
- `args.bundleId` for any explicit iOS bundle identifier

If no target is provided, the app commands default to the app bundle configured for the current session.

Artifacts remain under `automation/appium/output/`.

Explorer output controls:

- `ui.summary` accepts `limit`, `matchText`, and `visibleOnly`.
- `ui.inspect` accepts `limit`, `labels`, `tree`, `elements`, `source`, `screenshot`, `matchText`, `compact`, `interactiveOnly`, and `visibleOnly`.
- `ui.labels` accepts `limit`, `matchText`, `interactiveOnly`, and `visibleOnly`.
- `ui.tree` accepts `limit`, `matchText`, `compact`, `interactiveOnly`, and `visibleOnly`.

Recommended Settings workflow when output volume matters:

1. Start with `ui.summary` and a small `limit`.
2. Add `matchText` before falling back to `ui.inspect`.
3. For manual Settings exploration, prefer `ui.inspect` with `compact: true`, `interactiveOnly: true`, and often `visibleOnly: true`.
4. Use `make appium-explore-session APP_INSTALL=0` for repeated harness-only iterations once the current workspace build is already installed on device.

Dynamic Settings workflow:

1. Switch to Settings with `app.activate`.
2. Use `ui.summary` or `ui.inspect` to read the visible hierarchy.
3. If the screen exposes a search field, use `ui.search` to narrow the view dynamically, but do not assume Settings search indexes every page (for example, DNS may return no hits).
4. Open rows with `ui.tap`, navigate back with `ui.back`, and read switch state with `ui.read`.

Hint only: DNS is usually under General, then VPN & Device Management, then DNS. The explorer intentionally does not hard-code a locale-aware Settings path catalog, so prefer live discovery from the current hierarchy.

If the iPhone still shows `Automation Running` after `session.shutdown`, treat that as a cleanup bug in the harness. The intended behavior is that shutdown ends the active session without forcing a full WDA teardown. If the device-side automation state is stuck, retry with `APPIUM_WDA_HARD_RESET=1`.

If the session drops unexpectedly, first suspect device auto-lock or lost foreground automation. Unlock the device, restart the explorer session once, and only then treat it as an app or harness failure.

## Extending the Suite

- Add specs under `automation/appium/wdio/src/specs/` **and register them in the
  explicit `specs` list in `wdio.conf.ts`** (the glob was replaced so spec order
  is deterministic). **Group by account state: ALL inactive-account scenarios
  first, then ALL active-account scenarios** (the list has `--- inactive ---` /
  `--- active ---` markers). The suite ends with the device active (the last spec
  leaves it active). Put a new spec in its account group — don't interleave.
- **Why the grouping matters (cost):** an account restore is expensive (app
  relaunch + support-chat command + network round trip, ~1 min). `ensureAccount*`
  restores **only when the device isn't already on that account this run** — it
  tracks the last-restored account in `output/.account-state` (reset once per run
  by the `onPrepare` hook, so the first spec always restores and the device's
  leftover state is never trusted). With scenarios grouped, the account is
  restored just **once per group** (at the boundary), not once per spec. Interleaving
  still passes but forces an extra restore at every switch, so keep groups intact.
- Control account state with `flows/account.ts`: `ensureAccountActive()` /
  `ensureAccountInactive()` restore a dedicated account via the support-chat
  command bus (`cc restore <id>`), reading the ids from the
  `BLOKADA_ACTIVE_ACCOUNT_ID` / `BLOKADA_INACTIVE_ACCOUNT_ID` env (GitHub
  secrets in CI). `sendChatCommand(...)` can fire any `cc`-prefixed command.
  These ids are typed into the support chat (and echoed as a bubble), so they
  can appear in failure page-source / screenshot artifacts — use dedicated
  throwaway dev accounts, never a real customer account.
- Golden screenshots: `support/golden.ts` `compareToGolden(name, opts)`. Goldens
  live in `src/specs/smoke/__golden__/` and are device-resolution specific.
  Generate/refresh a baseline with `UPDATE_GOLDEN=1 make appium-test` on the
  target device, then commit the PNG.
- Use `driver.execute('mobile: ...')` helpers for Settings navigation (DNS/VPN flows).  
- Once stable, wire `make appium-test` into CI with a dedicated device lane.  
- When the app exposes stable accessibility identifiers, update selectors to drop the localization fallbacks.
- Mirror any new automation targets in Flutter by adding identifiers to `common/lib/src/shared/automation/ids.dart` and wiring them through `Semantics` widgets.
