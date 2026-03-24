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
   
After this, Appium can build WDA on demand using the same signing profile.

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

- Add specs under `automation/appium/wdio/src/specs/`.  
- Use `driver.execute('mobile: ...')` helpers for Settings navigation (DNS/VPN flows).  
- Once stable, wire `make appium-test` into CI with a dedicated device lane.  
- When the app exposes stable accessibility identifiers, update selectors to drop the localization fallbacks.
- Mirror any new automation targets in Flutter by adding identifiers to `common/lib/src/shared/automation/ids.dart` and wiring them through `Semantics` widgets.
