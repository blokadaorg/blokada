# Running on iOS Simulator

Mocked-scheme Makefile targets build and launch the app on a per-checkout
iOS Simulator. System integrations the sim can't run are stubbed at the
service layer (`NetxServiceMock`, `PrivateDnsServiceMock`,
`QuickActionsService`, `LoggerSaverMock`); Adapty is stubbed via
`MockPaymentChannel` (StoreKit2 can't fetch products in a sim). Everything
else — account, devices, profiles, schedules, blocklists, stats — hits the
real backend. The fast path for UX, notifications, settings, and any
feature work that benefits from exercising the real iOS↔API wire.

## One-time setup

```bash
make pods                                          # once per checkout
$EDITOR common/lib/dev_seed.dart                   # fill in dev IDs
```

`dev_seed.dart` is committed with `REPLACE_WITH_*` placeholders so the
codebase always builds; the mocked entries fail fast with a clear error if
you launch one without filling in the IDs. Use a pre-provisioned dev account
per flavor (Family + v6/cloud) so the simulator doesn't provision throwaway
prod accounts on first launch. The seed is written to secure storage once;
real `account.fetch()` overwrites with the live state on next refresh.

Your edits to `dev_seed.dart` will show as a working-copy change in
`jj status` / `git status` and are easy to commit by accident. Mitigations:

- Visually scan your diff before every `jj commit` / `git add`; if you see
  `dev_seed.dart` and don't intend to ship it, leave it out.
- Git-side only: `git update-index --skip-worktree common/lib/dev_seed.dart`
  makes git pretend the file is unchanged. Equivalent isn't built into jj.

## Quick start

From `ios/`:

```bash
make run-six-mocked      # or run-family-mocked
```

First invocation auto-clones a sim named `iPhone 16 - <parent-dir>`.
Worktrees each get their own, so two checkouts can run in parallel.

Overrides: `SIM_BASE="iPhone 15"`, `NAME=custom`, `SIM_TEMPLATE="warm sim"`.

## When to use what

| Goal | Path |
|---|---|
| UX, notifications, account state, settings, API wire integration | `make run-*-mocked` (sim) |
| Real DNS/VPN, NetworkExtension verification, paywall flow | `make run-six` (device) |
| App Store binary | `make ipa-six` / `ipa-family` (unchanged) |

## Appium targeting

The harness opts into the per-worktree sim via `IOS_USE_SIM=1`. It reads the
sim's UDID from `make -C ios sim-status`, installs the Mocked / FamilyMocked
build via the matching `appium-install-*-mocked` target, and skips the
device-only signing capabilities and `devicectl`-based WDA process inspection.

```bash
# interactive JSONL session against the sim
IOS_USE_SIM=1 make appium-explore-session
# Family flavor
IOS_USE_SIM=1 APP_FLAVOR=family make appium-explore-session
# already-installed app, skip reinstall
IOS_USE_SIM=1 APP_INSTALL=0 make appium-explore-session
```

`make run-{six,family}-mocked` must have been run at least once for the sim
to exist; `appium-explore-session` does not provision the sim itself.

Raw bash equivalent if you'd rather drive Appium directly:

```bash
SIM_UDID=$(make -C ios sim-status | sed -n 's/^SIM_UDID: *//p')
appium --udid "$SIM_UDID" ...
```

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
- **Seed persists across app uninstall.** The dev-account seed lands in the simulator's secure storage and stays even after deleting the app. Use `make sim-clean` to wipe the whole sim if a cold-start scenario is needed.
- **Real API side effects.** The sim hits production `api.blocka.net` / `family.api.blocka.net`. Device registrations land on the dev account; parallel worktrees sharing one account both register entries (often useful — more devices to iterate against).
- **Adapty / paywall is a no-op.** `MockPaymentChannel` logs but does nothing; if you need to iterate on paywall UI itself, use `make run-six` against a device.
- **Shared app group `group.net.blocka.app`.** All sim runs share one container; Mocked usually regenerates state per launch so this rarely bites.
- **Mocked and FamilyMocked share `net.blocka.app` on the sim.** Both Xcode targets emit the same `PRODUCT_BUNDLE_IDENTIFIER`, so flipping flavor is uninstall + install on the same sim, not a parallel install. Run `make sim-clean && make run-{six,family}-mocked` to switch. For true parallel two-flavor work, use two worktrees (each gets its own sim).
- **Device coexistence is not supported.** `make run-six` always installs `net.blocka.app` and overwrites prior installs.
- **`common/` rebuilds per worktree.** Run `make -C ../common build-ios` once per worktree.
- **Sims accumulate disk + clutter Xcode's device list.** `make sim-clean` per worktree, `make sim-gc` after Xcode upgrades.
- **`simctl clone` can be flaky after Xcode runtime upgrades.** Try `make sim-gc` and re-run.
- **Xcode SCM features (Blame, Log) don't work from a git worktree.** Use CLI git/jj, or open the main checkout for SCM.
