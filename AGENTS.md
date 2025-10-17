# Agent Notes

This repository contains the Android and iOS projects for Blokada 6. The main directories are:

- `common/` – Flutter module shared between Android and iOS.
- `android/` – Gradle project building the Android apps.
- `ios/` – Xcode project for iOS.
- `scripts/` – helper scripts.
- `deps/` and other archives – tools bundled with the repository.

The top level `Makefile` orchestrates building both platforms. Flutter related
work is handled in `common/Makefile`.

Makefiles are tab indented, so be careful when editing them.

## Tests

`make test` runs the Flutter tests located in `common/`. These require the
Flutter dependencies to be available locally.

In sandboxed environments where network trust stores cannot be modified, prefer
running `make -C common test`. The top-level `make test` target invokes
`fvm flutter pub get` before testing, which attempts to update dependencies and
can fail with `CERTIFICATE_VERIFY_FAILED` when the sandbox blocks certificate
installation.

## iOS Appium Smoke Test

- The WebdriverIO + Appium harness lives under `automation/appium/wdio/`.
- Device/WebDriverAgent setup steps are documented in `automation/appium/README.md`
  (UI testing toggle, installing Appium + xcuitest driver, opening WDA in Xcode,
  setting the development team, and running the initial install).
- Run the launch smoke test with `make appium-test`. Optional overrides:
  - `IOS_DEVICE_NAME=<name>` to select a connected device by name.
  - `IOS_UDID=<udid>` to target a specific device directly.
- The test spawns the global Appium CLI; when executed from automations or
  assistants, be prepared to request elevated permission so the process can
  access the device and CoreSimulator services.
- The harness takes roughly a minute end-to-end. If `make appium-test` is
  launched through the CLI tools, bump the command timeout (e.g.
  `timeout_ms: 180000`) so the wrapper does not abort at the default 90 s.
- Test artifacts (screenshots and UI XML dumps) are written to
  `automation/appium/output/` after each run:  
  `wdio-launch-foreground.png`, `wdio-after-power.png`, and
  `wdio-launch-foreground.xml`.
- The reusable flows live under `automation/appium/wdio/src/flows/` and the
  primary smoke spec is `automation/appium/wdio/src/specs/smoke/dns-onboarding.spec.ts`.
  Assistants can invoke these specs to validate behaviour on a real device
  (notification handling, DNS provisioning, screenshots, etc.) before or after
  making code changes.
