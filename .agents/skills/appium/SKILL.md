---
name: appium
description: Use for dynamic inspection and navigation of the Blokada app through the repo-local Appium machine session. Trigger when Codex needs to explore the live native UI on a real device, inspect labels or structure, tap through screens, capture screenshots or XML on demand, or verify interactive behavior without writing a static WDIO spec. The current workflow is implemented for iOS, but the skill name stays generic so it can later cover other Appium-backed platforms too.
---

# Appium

Use the repo-local machine session only. Do not create temporary WDIO debug specs for ad hoc inspection.

## Start the session

Prefer the root make target:

```bash
make appium-explore-session IOS_DEVICE_NAME="<device-name>"
```

Important:
- In Codex, request elevated access before running the Appium explorer, install targets, or related device-discovery commands. These flows depend on `xcrun` device services, WebDriverAgent/Appium startup, and real-device interaction that the sandbox cannot reliably access.
- Do not assume the make target can auto-discover the device inside the sandbox. If you need the connected phone, run the command with elevated access from the start.
- When invoking repo make targets, keep the command prefix stable as `make <target> ...` and put any make variable overrides after the target, for example `make appium-explore-session APP_INSTALL=0 SHOW_XCODE_LOG=0`. Avoid shell-style env prefixes like `APP_INSTALL=0 make ...`, because they create unnecessary sandbox permission prompt variants.

Notes:
- This installs the current workspace build by default. Use this for reviews of current changes, startup behavior, cold-start behavior, notification handling, and other recent code changes.
- Use `APP_FLAVOR=family` when the primary app under test should be Blokada Family. The default primary flavor is Blokada 6.
- A session started with the default flavor only freshly installs Blokada 6. `app.targets` may still list `family` if Family is already on the device, but that is a reused install unless you also ran a fresh `APP_FLAVOR=family` session in the same turn.
- Use `APP_INSTALL=0` only when you already installed the current workspace build in the same turn, or when you have high confidence the installed app still matches the code you want to inspect.
- `APP_BUNDLE_ID` may override the primary bundle id, but if it does not match the intended flavor, set `APP_FLAVOR` explicitly so the install target stays correct.
- `IOS_DEVICE_NAME` is the normal device selector for the current iOS flow.
- `IOS_UDID` is a low-level fallback only.
- Interactive sessions must preserve the device's current Auto-Correction and Predictive settings. Do not add Settings navigation to the tests for this; keep the fix in the Appium/WDA layer.
- Real-device sessions should normally reuse an existing WebDriverAgent if one is healthy. End the active session cleanly, but reserve a full device-side WDA kill for explicit recovery such as `APPIUM_WDA_HARD_RESET=1`.
- If you do not expect to continue testing immediately, always shut the session down before you step away. Do not leave a device sitting in automation mode with the `Automation Running` banner visible.
- Appium does not manage iOS auto-lock for us. Before a long session, set Auto-Lock to `Never` or the longest available value and keep the device unlocked before starting.
- The process stays open and accepts JSONL commands on stdin.

## Drive the session

Send one JSON object per line to stdin. Wait for the terminal `done` or `error` event before sending the next command.

Request shape:

```json
{"id":"1","command":"ui.summary","args":{}}
```

Response lifecycle:
- `ack`
- optional `result`
- terminal `done` or `error`

Use these commands:
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

## Default workflow

Use this sequence unless the task requires something else:

1. Request elevated access first so device discovery, install, Appium, and WebDriverAgent can talk to the connected iPhone.
2. Start with a fresh install by default so the app on device matches the current workspace.
3. Send `session.status` to confirm the session and app state.
4. If the app version/build on device is not clearly tied to the current workspace, stop and reinstall instead of trusting the existing install.
   For example: if you start a fresh `six` session and then switch to `family`, treat that Family app as untrusted unless you separately ran `make appium-explore-session APP_FLAVOR=family`.
5. Use `app.targets` when you need to switch between `six`, `family`, and iOS Settings without restarting the session.
6. Use `app.activate` with `args.target`, for example `six`, `family`, or `settings`.
7. Use `ui.summary` as the fast default inspection command while navigating the current foreground app. It now reports the verified foreground target and active app metadata instead of trusting app state alone.
8. Use `ui.inspect` when you need bounded structure details. By default it includes labels, a tree summary, and a structured visible-element list.
9. Use `ui.read` to normalize common element attributes such as `value`, `enabled`, `visible`, and switch-like boolean state.
10. Use `ui.focusSearch`, `ui.search`, `ui.back`, `ui.swipe`, and `ui.scroll` for dynamic system-app exploration without creating a temporary static spec.
11. Use `ui.screenshot` or `ui.source` only when you need artifacts.
12. Always finish with `session.shutdown`. This should end the active session without forcing a full WDA reset.
13. If you are done for now, do not keep the session open just to preserve reuse. Reuse matters between active test runs, but an idle phone should not be left showing `Automation Running`.

If the session drops unexpectedly, first suspect device auto-lock or lost foreground automation:

- unlock the device
- confirm whether the app is still installed / in foreground
- restart the explorer session once before concluding the app itself broke

If Appium never reaches JSONL command handling after install and the server log shows repeated `/status` socket hangups, `iProxy ... Unexpected data`, or WebDriverAgent `xcodebuild` code `65`, treat that as a harness/WDA problem first:

- retry the explorer once
- inspect `automation/appium/output/appium-explore-server.log`
- do not treat the app under test as failed unless the same behavior also reproduces after WDA is healthy

When reporting findings from an interactive session, state whether the session used a freshly installed workspace build or a trusted reused install.

## Command guidance

Prefer `ui.summary` first:

```json
{"id":"1","command":"ui.summary","args":{}}
```

Use `ui.inspect` for bounded structure:

```json
{"id":"2","command":"ui.inspect","args":{"labels":true,"tree":true,"limit":40}}
```

Use generic navigation and reads for dynamic exploration:

```json
{"id":"3","command":"ui.search","args":{"text":"keyboard"}}
{"id":"4","command":"ui.tap","args":{"selector":"~Keyboard"}}
{"id":"5","command":"ui.read","args":{"selector":"~Auto-Correction"}}
{"id":"6","command":"ui.back","args":{}}
{"id":"7","command":"ui.scroll","args":{"direction":"down"}}
```

Use raw WDIO/Appium selectors directly:

```json
{"id":"8","command":"ui.tap","args":{"selector":"~Privacy Pulse"}}
{"id":"9","command":"ui.wait","args":{"selector":"~Avancerat","timeoutMs":10000}}
{"id":"10","command":"ui.attr","args":{"selector":"~automation.power_toggle","name":"value"}}
```

Switch between the built-in app targets without restarting Appium:

```json
{"id":"11","command":"app.targets","args":{}}
{"id":"12","command":"app.activate","args":{"target":"family"}}
{"id":"13","command":"ui.summary","args":{}}
{"id":"14","command":"app.activate","args":{"target":"settings"}}
{"id":"15","command":"app.activate","args":{"target":"six"}}
```

For dynamic Settings work, prefer discovery over a maintained path catalog:
- switch to `settings`
- use `ui.summary` and `ui.inspect` to see the visible hierarchy
- use `ui.search` if the screen exposes a search field
- open rows and read switches dynamically with `ui.tap` and `ui.read`

Lightweight hint only: DNS is usually under `General`, then `VPN & Device Management`, then `DNS`, but use the live hierarchy instead of assuming labels or locale.

Practical DNS notes:
- Treat DNS as a top-level system setting reached from `Settings` -> `General` -> the VPN/DNS management area. The exact row labels depend on locale, but it is not an app-specific setting under the Blokada app entry.
- A failed Settings search for `DNS` is not enough to conclude the path is unavailable; prefer live hierarchy discovery.
- If tapping the visible VPN/DNS management row is unreliable, try the accessibility id when present.
- If the task is to put DNS "back", first verify the current selection on the DNS screen. If `Automatic` is already selected, leave it unchanged instead of toggling away and back.

Capture artifacts only when needed:

```json
{"id":"16","command":"ui.screenshot","args":{"name":"settings-screen"}}
{"id":"17","command":"ui.source","args":{"name":"settings-screen"}}
```

## Cleanup

Always send:

```json
{"id":"999","command":"session.shutdown","args":{}}
```

The intended behavior is that shutdown removes active automation from the phone without discarding reusable WDA state. If the iPhone still shows `Automation Running`, treat it as a harness cleanup bug and use an explicit hard reset rather than normalizing full WDA teardown after every run.
