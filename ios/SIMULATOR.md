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
make -C ../common build-ios                        # build the Flutter xcframeworks the app embeds
```

The dev account ID is supplied to the build at compile-time as a
`--dart-define`. It seeds an active account into secure storage on first
launch so the paywall / first-account-create flow never runs; real
`account.fetch()` overwrites with the live state on next refresh. Use a
pre-provisioned dev account per flavor (Family + v6/cloud) so the simulator
doesn't provision throwaway prod accounts.

The mocked build has no paywall or purchase flow (StoreKit and the payment
channel are stubbed), so the dev account you supply must already be active. An
inactive or expired account leaves the app deactivated with no in-app way to
upgrade it. Also note that `seedDevAccount` only seeds when no account is stored
yet, so a reused simulator keeps whatever account was last persisted, including
an inactive throwaway the app may create after refreshing an inactive account.
To switch to a different `ACCOUNT_ID`, start from a clean simulator
(`make sim-clean`) or restore the account from the app's settings.

The Mocked / FamilyMocked schemes build the same `lib/main.dart` entrypoint as
the shipping app; mocked behavior is switched on by the `MOCKED=true` and
`FLAVOR` dart-defines that the make layer folds (with `ACCOUNT_ID`) into the
`DART_DEFINES` it passes to xcodebuild. There is no separate mocked entrypoint
and no Mocked-specific Xcode build-phase edit, so `pod install` cannot clobber
the mocked build config.

Two ways to provide the ID:

```bash
# Option A — pass on the command line (good for AI-agent / one-off invocations)
ACCOUNT_ID=xxx make run-six-mocked

# Option B — drop a gitignored .env.local at the repo root (set once, reuse)
cat > ../.env.local <<EOF
SIX_DEV_ACCOUNT_ID=xxx
FAMILY_DEV_ACCOUNT_ID=yyy
EOF
make run-six-mocked       # picks SIX_DEV_ACCOUNT_ID from .env.local
make run-family-mocked    # picks FAMILY_DEV_ACCOUNT_ID from .env.local
```

CLI `ACCOUNT_ID=...` always wins over `.env.local`. If neither is set the
build proceeds and the app throws a clear `StateError` at boot.

## Quick start

From `ios/`:

```bash
ACCOUNT_ID=xxx make run-six-mocked      # or run-family-mocked
```

First invocation auto-clones a sim named `iPhone 17 - <parent-dir>`.
Worktrees each get their own, so two checkouts can run in parallel.

Overrides: `SIM_BASE="iPhone 15"`, `NAME=custom`, `SIM_TEMPLATE="warm sim"`.
`SIM_BASE` defaults to `iPhone 17` (what a current Xcode installs); if that
model isn't installed, pass one from `xcrun simctl list devices available`.

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
to exist; `appium-explore-session` does not provision the sim itself. If you
created the sim with a non-default `SIM_BASE`, pass the same value here so
`sim-status` resolves the matching UDID (e.g.
`IOS_USE_SIM=1 SIM_BASE="iPhone 15" make appium-explore-session`).

Raw bash equivalent if you'd rather drive Appium directly:

```bash
SIM_UDID=$(make -C ios sim-status | sed -n 's/^SIM_UDID: *//p')
appium --udid "$SIM_UDID" ...
```

## Warm-state template

Default clones from a fresh `iPhone 17`, so first launch in each new
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
