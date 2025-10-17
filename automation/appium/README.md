# Appium WebdriverIO Harness

This folder contains the WebdriverIO + TypeScript suite that drives Appium
against the Blokada 6 iOS app on physical devices.

## One-Time Device & WebDriverAgent Setup

1. **Enable UI testing on the device**  
   Settings ▸ Privacy & Security ▸ Developer Mode ▸ turn on “UI Testing”.
2. **Install Appium CLI**  
   ```bash
   brew install appium
   ```
3. **Install the xcuitest driver**  
   ```bash
   appium driver install xcuitest
   ```
4. **Open the bundled WebDriverAgent project**  
   ```bash
   appium driver run xcuitest open-wda
   ```
5. **Configure signing in Xcode**  
   - Select the `WebDriverAgentRunner` scheme.  
   - Choose your physical device (e.g., “Johnny”).  
   - In Signing & Capabilities set *Development Team* to **HQH5AFGB68** (or your own team if you fork the app).
6. **Build/run once from Xcode**  
   
After this, Appium can build WDA on demand using the same signing profile.

## Running the Tests

```bash
make appium-test
```

Optional overrides:

- `IOS_DEVICE_NAME=Johnny make appium-test` – pick a device by name (script matches the first connected device whose name contains the value).
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

## Extending the Suite

- Add specs under `automation/appium/wdio/src/specs/`.  
- Use `driver.execute('mobile: ...')` helpers for Settings navigation (DNS/VPN flows).  
- Once stable, wire `make appium-test` into CI with a dedicated device lane.  
- When the app exposes stable accessibility identifiers, update selectors to drop the localization fallbacks.
- Mirror any new automation targets in Flutter by adding identifiers to `common/lib/common/automation/ids.dart` and wiring them through `Semantics` widgets.
