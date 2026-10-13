---
name: emulator
description: Use to run and inspect the Blokada Android app on a Google Developer Device Platform emulator, with screenshots and UI dumps, from a Claude Code cloud session or a local machine without an Android emulator. Trigger when a change under common/ affects UI and should be checked on a device before a PR, and no local emulator or device is available.
---

# Emulator

`tools/emu/emu` reserves an Android emulator (`MediumPhone.arm`) from Google's Developer Device Platform and drives it through a pod on the `workbench` GKE cluster. The session itself cannot hold the ADB stream, so every command runs on the pod and its output is relayed back. The Google project, cluster and bucket are derived from `gcloud config get project`.

Locally it needs gcloud logged in with the staging project active and access there, plus kubectl, curl and python3; no emulator or Android SDK for `emu` itself, though building the APK still needs the Android toolchain.

Use it to check UI changes in `common/` before opening a PR. Not for iOS, and not for anything needing a VPN permission prompt answered by a real user.

## Commands

```bash
tools/emu/emu up [--version 36] [--ttl 30m]   # reserve, build or reuse the pod image, wait until the device is online
tools/emu/emu install path/to/app.apk         # adb install -r
tools/emu/emu adb 'shell am start -n <pkg>/<activity>'
tools/emu/emu adb 'shell input tap 540 1200'
tools/emu/emu shot [file.png]                 # screenshot into the session, default ./shot.png
tools/emu/emu ui [file.xml]                   # uiautomator dump, default ./ui.xml
tools/emu/emu down                            # cancel the session, delete the pod, clear the bucket prefix
```

`emu adb` takes one string of adb arguments and returns adb's exit code. The exit code of the command inside `adb shell` does not come back over the device stream, so check its output instead. Read screenshots with the Read tool; use `emu ui` to find tap coordinates from element bounds.

## Workflow

1. Build the mocked debug APK: `make build-android-six-debug-mocked`, then `android/app/build/outputs/apk/six/debug/app-six-debug.apk`. Launch it with `emu adb 'shell am start -n org.blokada.sex/ui.MainActivity'`.
2. Run `emu up` as a background command. It takes about 1 minute on a warm cluster and up to 5 on a cold one, and longer on the first run of a changed `tools/emu/pod` because the image is built with Cloud Build.
3. `emu install`, drive the app with `emu adb`, check with `emu shot` and `emu ui`. Run slow commands as background commands.
4. Always finish with `emu down`, also after a failure. Reserved devices are billed until the TTL ends. `emu up` cleans up after itself when it fails.

## Limits

- One session at a time per `~/.cache/emu`; `emu up` refuses while one exists.
- A reserved device expires at the TTL; `up` defaults to 30 minutes. Reserve again rather than extending.
- Files move through the bucket, so APKs and screenshots are not limited by the 8 MB proxy request body cap.
- The first calls after a cold cluster may wait up to about 75 s on `503 No agent available`; `emu` retries them.
