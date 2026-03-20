---
name: device-log
description: Use for pulling recent Blokada app logs from a connected device, using the same share-log file exposed in Settings. Trigger when Codex needs the most recent app log lines for debugging, wants logs from the last hour or today, or needs a manual operator workflow for recent device logs without going through Appium UI automation.
---

# Device Log

Use this skill when the task is to read the recent Blokada shared app log or crash report from a connected device.

The current implementation supports iOS real devices only. Keep the skill name generic so Android can be added later without splitting the workflow again.

This skill reads the same share-log file exposed in Settings, then filters it on the host. It does not drive UI automation.

## Default command

In Codex, request elevated access before running the command. The iOS device services are not reliably reachable from the sandbox.

Prefer the dedicated automation script:

```bash
node automation/device/log.mjs
```

Optional overrides:

```bash
WINDOW=today node automation/device/log.mjs
LINES=800 node automation/device/log.mjs
IOS_DEVICE_NAME="Example iPhone" node automation/device/log.mjs
APP_BUNDLE_ID=net.blocka.app.family node automation/device/log.mjs
ARTIFACT=crash node automation/device/log.mjs
ARTIFACT=crash APP_BUNDLE_ID=net.blocka.app.family node automation/device/log.mjs
```

Default behavior:
- auto-selects the first connected device when no device selector is provided
- reads the last hour of the shared app log
- returns up to `400` lines after time filtering
- saves artifacts under `automation/device/output/`

Supported variables:
- `ARTIFACT` defaults to `log`, supports `log` or `crash`
- `IOS_DEVICE_NAME`
- `IOS_UDID`
- `APP_BUNDLE_ID` defaults to `net.blocka.app`
- `WINDOW` defaults to `1h`, supports `1h` or `today`
- `LINES` defaults to `400`

## Behavior

- `ARTIFACT=log`:
  - pulls the share-log file from the app group container `group.net.blocka.app`
  - chooses the newest matching file for the selected bundle:
    - `net.blocka.app` -> `blokada-i6x*.log`
    - `net.blocka.app.family` -> `blokada-iFx*.log`
  - filters on the host for the last hour or today
  - applies `LINES` after time filtering
  - saves artifacts under `automation/device/output/logs/`
- `ARTIFACT=crash`:
  - lists the `systemCrashLogs` domain
  - chooses the newest matching file for the selected bundle:
    - `net.blocka.app` -> `Dev-*.ips`
    - `net.blocka.app.family` -> `FamilyDev-*.ips`
  - saves artifacts under `automation/device/output/crashlogs/`

## Notes

- `ARTIFACT=log` reads the Settings share-log equivalent, not `blokada.log`.
- `ARTIFACT=crash` is the post-mortem path when the app already terminated or Appium cannot stay attached.
- If no matching share-log file exists, treat that as a tooling or app-state problem and report it clearly.
