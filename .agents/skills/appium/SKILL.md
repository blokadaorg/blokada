---
name: appium
description: Use for dynamic inspection and navigation of the Blokada app through the repo-local Appium machine session. Trigger when Codex needs to explore the live native UI on a real device, inspect labels or structure, tap through screens, capture screenshots or XML on demand, or verify interactive behavior without writing a static WDIO spec. The current workflow is implemented for iOS, but the skill name stays generic so it can later cover other Appium-backed platforms too.
---

# Appium

Use the repo-local machine session only. Do not create temporary WDIO debug specs for ad hoc inspection.

## Start the session

Prefer the root make target:

```bash
make appium-explore-session IOS_DEVICE_NAME="<device-name>" APP_INSTALL=0
```

Notes:
- Omit `APP_INSTALL=0` when you need a fresh install first.
- `IOS_DEVICE_NAME` is the normal device selector for the current iOS flow.
- `IOS_UDID` is a low-level fallback only.
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

## Default workflow

Use this sequence unless the task requires something else:

1. Send `session.status` to confirm the session and app state.
2. Use `ui.summary` as the fast default inspection command while navigating.
3. Use `ui.tap`, `ui.wait`, `ui.exists`, and `ui.attr` to move through the UI.
4. Use `ui.inspect` only when bounded structure details are needed.
5. Use `ui.screenshot` or `ui.source` only when you need artifacts.
6. Always finish with `session.shutdown`.

## Command guidance

Prefer `ui.summary` first:

```json
{"id":"1","command":"ui.summary","args":{}}
```

Use `ui.inspect` for bounded structure:

```json
{"id":"2","command":"ui.inspect","args":{"labels":true,"tree":true,"limit":40}}
```

Use raw WDIO/Appium selectors directly:

```json
{"id":"3","command":"ui.tap","args":{"selector":"~Privacy Pulse"}}
{"id":"4","command":"ui.wait","args":{"selector":"~Avancerat","timeoutMs":10000}}
{"id":"5","command":"ui.attr","args":{"selector":"~automation.power_toggle","name":"value"}}
```

Capture artifacts only when needed:

```json
{"id":"6","command":"ui.screenshot","args":{"name":"settings-screen"}}
{"id":"7","command":"ui.source","args":{"name":"settings-screen"}}
```

## Cleanup

Always send:

```json
{"id":"999","command":"session.shutdown","args":{}}
```

The intended behavior is that shutdown removes WebDriverAgent automation from the phone. If the iPhone still shows `Automation Running`, treat it as a harness cleanup bug and inspect leftover WDA/device processes rather than leaving the session hanging.
