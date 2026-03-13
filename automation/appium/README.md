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
   - In Signing & Capabilities set *Development Team* to **HQH5AFGB68** (or your own team if you fork the app).
4. **Build/run once from Xcode**  
   
After this, Appium can build WDA on demand using the same signing profile.

## Static Smoke Tests

```bash
make appium-test
```

Optional overrides:

- `IOS_DEVICE_NAME="<device-name>" make appium-test` – pick a device by name (script matches the first connected device whose name contains the value).
- `IOS_UDID=<udid> make appium-test` – skip the selector entirely and target a specific UDID.
- `APP_BUNDLE_ID=…` – run against a different bundle id (defaults to `net.blocka.app`).
- `SHOW_XCODE_LOG=0` – suppress verbose xcodebuild output.
- `IOS_AUTO_SELECT_FIRST=1` – skip interactivity and use the first paired physical device (enabled automatically in CI).

The target now performs the full device reset cycle for the six flavor:

1. Auto-detects or resolves the target device (`IOS_UDID`) via `scripts/select-device.mjs` (interactive only when multiple devices are attached).
2. Builds the latest Dev scheme with `ios/appium-install-six`, removes existing installs, and deploys the fresh `.app` via `devicectl`.
3. Launches the WebdriverIO smoke suite.

Artifacts are saved in `automation/appium/output/`:

- `wdio-launch-foreground.png` – app state before tapping.  
- `wdio-after-power.png` – app state after the interaction.  
- `wdio-launch-foreground.xml` – raw UI hierarchy for selector debugging.
- `*.log` – captured syslog excerpts when a test fails, alongside failure-specific screenshots and XML dumps.

Reusable flows and helpers live under `automation/appium/wdio/src/flows/` and `automation/appium/wdio/src/support/`. Specs in `src/specs/smoke/` compose these flows to exercise end-to-end journeys.

## Machine Session

```bash
make appium-explore-session
```

Optional overrides:

- `IOS_DEVICE_NAME="<device-name>" make appium-explore-session` – target a specific connected device.
- `IOS_UDID=<udid> make appium-explore-session` – force a specific device UDID.
- `APP_INSTALL=0 make appium-explore-session` – skip reinstalling the app before connecting.
- `SHOW_XCODE_LOG=0 make appium-explore-session` – reduce WebDriverAgent build noise.

The session host opens one long-lived Appium/WebDriver session and communicates over newline-delimited JSON on stdin/stdout. Requests are JSON objects:

```json
{"id":"1","command":"session.status","args":{}}
{"id":"2","command":"ui.summary","args":{}}
{"id":"3","command":"ui.tap","args":{"selector":"~Privacy Pulse"}}
{"id":"4","command":"session.shutdown","args":{}}
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
- `app.launch`
- `app.activate`
- `app.terminate`
- `app.state`
- `ui.summary`
- `ui.inspect`
- `ui.tap`
- `ui.type`
- `ui.wait`
- `ui.exists`
- `ui.attr`
- `ui.source`
- `ui.screenshot`

Default machine workflow:

1. Use `session.status` to confirm the session is alive.
2. Use `ui.summary` as the fast default inspection command while navigating.
3. Use `ui.inspect` only when you need bounded structure details.
4. Use `ui.screenshot` or `ui.source` only when you need visual or raw-hierarchy artifacts.
5. Always finish with `session.shutdown` so the device exits automation mode cleanly.

Artifacts remain under `automation/appium/output/`.

If the iPhone still shows `Automation Running` after `session.shutdown`, treat that as a cleanup bug in the harness. The intended behavior is that shutdown tears down WebDriverAgent/XCTest without requiring manual phone cleanup.

## Extending the Suite

- Add specs under `automation/appium/wdio/src/specs/`.  
- Use `driver.execute('mobile: ...')` helpers for Settings navigation (DNS/VPN flows).  
- Once stable, wire `make appium-test` into CI with a dedicated device lane.  
- When the app exposes stable accessibility identifiers, update selectors to drop the localization fallbacks.
- Mirror any new automation targets in Flutter by adding identifiers to `common/lib/src/shared/automation/ids.dart` and wiring them through `Semantics` widgets.
