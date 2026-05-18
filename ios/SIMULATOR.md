# Running on iOS Simulator

Mocked-scheme Makefile targets build and launch the app on a per-checkout
iOS Simulator via `NetxServiceMock` (a fake NetworkExtension). The fast
path for UX, notifications, settings, account state — anything that
doesn't need real DNS/VPN packets.

## Quick start

From `ios/`:

```bash
make pods                # once per checkout
make run-six-mocked      # or run-family-mocked
```

First invocation auto-clones a sim named `iPhone 16 - <parent-dir>`.
Worktrees each get their own, so two checkouts can run in parallel.

Overrides: `SIM_BASE="iPhone 15"`, `NAME=custom`, `SIM_TEMPLATE="warm sim"`.

## When to use what

| Goal | Path |
|---|---|
| UX, notifications, account state, settings | `make run-*-mocked` (sim) |
| Real DNS/VPN, NetworkExtension verification | `make run-six` (device) |
| App Store binary | `make ipa-six` / `ipa-family` (unchanged) |

## Appium targeting

```bash
SIM_UDID=$(make -C ios sim-status | sed -n 's/^SIM_UDID: *//p')
appium --udid "$SIM_UDID" ...
```

Or `make appium-install-*-mocked` (installs without launching, prints UDID).
The existing `make appium-test` is device-only today — sim-aware
extension is a follow-up.

## Warm-state template

Default clones from a fresh `iPhone 16`, so first launch in each new
checkout has to redo onboarding. To skip that, pre-warm one sim and
point clones at it via `SIM_TEMPLATE`:

```bash
# one-time: create, boot, install, log in, then shut down
RUNTIME=$(xcrun simctl list runtimes available | awk '/iOS/{r=$NF} END{print r}')
xcrun simctl create "warm template" "iPhone 16" "$RUNTIME"

# per checkout:
make run-six-mocked SIM_TEMPLATE="warm template"
```

The clone inherits keychain, NSUserDefaults, App Group container, and
installed apps from the template.

## Helpers

| Target | What |
|---|---|
| `make sim-status` | Show this checkout's sim name + UDID |
| `make sim-clean` | Delete this checkout's sim |
| `make sim-gc` | Delete orphaned sims (after Xcode runtime upgrades) |

## Caveats

- **Mocked is Debug-only.** Release builds of Mocked/FamilyMocked still hit the unguarded WireGuard path.
- **Shared app group `group.net.blocka.app`.** All sim runs share one container; Mocked usually regenerates state per launch so this rarely bites.
- **Device coexistence is not supported.** `make run-six` always installs `net.blocka.app` and overwrites prior installs.
- **`common/` rebuilds per worktree.** Run `make -C ../common build-ios` once per worktree.
- **Sims accumulate disk + clutter Xcode's device list.** `make sim-clean` per worktree, `make sim-gc` after Xcode upgrades.
- **`simctl clone` can be flaky after Xcode runtime upgrades.** Try `make sim-gc` and re-run.
- **Xcode SCM features (Blame, Log) don't work from a git worktree.** Use CLI git/jj, or open the main checkout for SCM.
