# Mocked-scheme simulator runner (worktree-aware).
#
# Runs the app on an iOS Simulator using the Mocked / FamilyMocked schemes
# (NetxServiceMock substitutes the real NetworkExtension). Works from any
# checkout with no setup. The simulator name is derived from the parent
# directory of `ios/`, so each parallel worktree automatically gets its
# own simulator and multiple worktrees can run in parallel without
# contention. See ios/SIMULATOR.md for usage.
#
# Variables (override on the make command line):
#   NAME         per-checkout label; defaults to basename of CURDIR/..
#   SIM_BASE     iPhone model used in the sim name (default: iPhone 17).
#                Must be an installed simulator model — check with
#                `xcrun simctl list devices available`. iPhone 17 is what a
#                current Xcode installs by default; override if yours differs.
#   SIM_TEMPLATE source sim to clone from (default: $(SIM_BASE) — fresh)
#                Set to a pre-warmed sim name to seed each new clone
#                with that sim's state (onboarding, logged in, etc.).

NAME         ?= $(notdir $(abspath $(CURDIR)/..))
SIM_BASE     ?= iPhone 17
SIM_TEMPLATE ?= $(SIM_BASE)
SIM_NAME     := $(SIM_BASE) - $(NAME)

# Repo-root .env.local: gitignored, optional. Sourced by run-mocked-app.
# Recognised keys: SIX_DEV_ACCOUNT_ID, FAMILY_DEV_ACCOUNT_ID, ACCOUNT_ID.
ENV_FILE     := $(abspath $(CURDIR)/..)/.env.local

# ACCOUNT_ID seeds the dev account into secure storage at boot. run-mocked-app
# resolves it and folds it (with MOCKED and FLAVOR) into the DART_DEFINES that
# the default Flutter build phase consumes, so there is no Mocked-specific
# build-phase edit for pod install to clobber. Resolution order in run-mocked-app:
#   1. ACCOUNT_ID env/CLI override (always wins)
#   2. Flavor-keyed value from $(ENV_FILE) (SIX_/FAMILY_DEV_ACCOUNT_ID)
#   3. Unset -> build proceeds; app fails fast at boot with a StateError.
export ACCOUNT_ID

# Literal `(` for use in shell strings — keeps Make's $(...) parser happy.
LPAREN := (

# Restricted to `available` so a stale clone (common after Xcode runtime
# upgrades, when its runtime is gone) is treated as missing — _ensure-sim
# then re-clones automatically instead of returning an unavailable UDID
# that boot/install would later fail on. Run `make sim-gc` to clear the
# stale entry from Xcode's device list.
sim-udid = $(shell xcrun simctl list devices available 2>/dev/null | awk -v needle="    $(SIM_NAME) $(LPAREN)" 'index($$0, needle) == 1 {print; exit}' | sed -E 's/.*\(([-0-9A-Fa-f]+)\).*/\1/')

.PHONY: sim-status sim-clean sim-gc \
	run-six-mocked run-family-mocked \
	appium-install-six-mocked appium-install-family-mocked \
	print-build-dir-scheme print-product-name-scheme \
	_ensure-sim _build-mocked

# Internal: echo this checkout's sim UDID; clone the sim if missing.
_ensure-sim:
	@UDID="$(sim-udid)"; \
	if [ -z "$$UDID" ]; then \
		SRC_UDID=$$(xcrun simctl list devices available | awk -v needle="    $(SIM_TEMPLATE) $(LPAREN)" 'index($$0, needle) == 1 {print; exit}' | sed -E 's/.*\(([-0-9A-Fa-f]+)\).*/\1/'); \
		if [ -z "$$SRC_UDID" ]; then \
			echo "Error: no available sim named '$(SIM_TEMPLATE)' to clone from. Try SIM_BASE=\"iPhone 15\" or SIM_TEMPLATE=<existing-sim>. Available:" >&2; \
			xcrun simctl list devices available | grep -E '^\s+iPhone' | head >&2; \
			exit 1; \
		fi; \
		CLONE_ERR=$$(mktemp); \
		UDID=$$(xcrun simctl clone "$$SRC_UDID" "$(SIM_NAME)" 2>"$$CLONE_ERR") || { \
			echo "Error: simctl clone failed (known to be flaky after Xcode upgrades — try \`make sim-gc\` and retry). Detail: $$(cat "$$CLONE_ERR")" >&2; \
			rm -f "$$CLONE_ERR"; \
			exit 1; \
		}; \
		rm -f "$$CLONE_ERR"; \
		echo "cloned '$(SIM_TEMPLATE)' -> '$(SIM_NAME)' ($$UDID)" >&2; \
	fi; \
	echo "$$UDID"

sim-status:
	@UDID="$(sim-udid)"; \
	echo "SIM_NAME: $(SIM_NAME)"; \
	if [ -n "$$UDID" ]; then echo "SIM_UDID: $$UDID"; else echo "SIM_UDID: (not cloned — will auto-clone on first run-*-mocked)"; fi

sim-clean:
	@UDID="$(sim-udid)"; \
	if [ -n "$$UDID" ]; then \
		echo "deleting '$(SIM_NAME)' ($$UDID)"; \
		xcrun simctl delete "$$UDID"; \
	else \
		echo "no simulator named '$(SIM_NAME)' to clean"; \
	fi

sim-gc:
	@echo "removing unavailable simulators (orphaned by Xcode runtime upgrades)..."
	xcrun simctl delete unavailable
	@echo "current iPhone/iPad sim count: $$(xcrun simctl list devices available 2>/dev/null | grep -cE '^\s+(iPhone|iPad)')"

# Internal: build-dir for any scheme, used by run-mocked-app macro.
print-build-dir-scheme:
	@$(call xcode-build-dir,$(SCHEME),Debug,$(DESTINATION))

# Internal: resolves the produced .app filename (FULL_PRODUCT_NAME) for any
# scheme. Needed because PRODUCT_NAME varies — Mocked builds as "Blokada
# Mocked.app", FamilyMocked as "FamilyMocked.app", etc.
print-product-name-scheme:
	@$(XCODEBUILD) -workspace $(XCODE_WORKSPACE) -scheme $(SCHEME) -configuration Debug $(if $(strip $(DESTINATION)),-destination '$(strip $(DESTINATION))') -showBuildSettings 2>/dev/null | awk -F'= ' '/FULL_PRODUCT_NAME/{print $$2; exit}'

# Internal: build any scheme via run-helpers' xcode-build macro. Lives on its
# own recipe line so the leading `@` in xcode-build is parsed as Make's silent
# prefix; inlining it inside a shell pipeline would leak the literal `@` and
# break bash.
#
# DART_DEFINES (carrying MOCKED, FLAVOR, and the base64-encoded ACCOUNT_ID) is
# propagated to xcodebuild as an environment variable by run-mocked-app, not as
# an xcodebuild user-defined build setting, so the account id does not appear in
# argv / `ps` output. The Flutter build phase reads DART_DEFINES from the env;
# flutter_export_environment.sh does not set it, so the value survives.
_build-mocked:
	$(call xcode-build,build,$(SCHEME),Debug,$(DESTINATION),)

# $(call run-mocked-app,scheme,mode)
#   scheme: Mocked or FamilyMocked (.app filename matches scheme name)
#   mode:   "launch" to foreground after install, "install" to just install
# Both Mocked and FamilyMocked use bundle ID net.blocka.app per existing
# project convention (see pbxproj entries for FamilyMocked).
define run-mocked-app
	@set -e; \
	UDID=$$($(MAKE) --no-print-directory _ensure-sim); \
	DEST="platform=iOS Simulator,id=$$UDID"; \
	ACCOUNT_ID=$$( \
		__cli="$${ACCOUNT_ID:-}"; \
		[ -f "$(ENV_FILE)" ] && . "$(ENV_FILE)"; \
		if [ -n "$$__cli" ]; then printf '%s' "$$__cli"; \
		elif [ -n "$${ACCOUNT_ID:-}" ]; then printf '%s' "$$ACCOUNT_ID"; \
		elif [ "$(1)" = "Mocked" ]; then printf '%s' "$${SIX_DEV_ACCOUNT_ID:-}"; \
		elif [ "$(1)" = "FamilyMocked" ]; then printf '%s' "$${FAMILY_DEV_ACCOUNT_ID:-}"; \
		fi \
	); \
	if [ -z "$${ACCOUNT_ID:-}" ]; then \
		echo "warning: ACCOUNT_ID not set (no CLI override, no $(ENV_FILE) entry). App will compile but throw StateError at boot. See ios/SIMULATOR.md." >&2; \
	fi; \
	if [ "$(1)" = "FamilyMocked" ]; then FLAVOR=family; else FLAVOR=six; fi; \
	D_MOCKED=$$(printf '%s' "MOCKED=true" | base64 | tr -d '\n'); \
	D_FLAVOR=$$(printf '%s' "FLAVOR=$$FLAVOR" | base64 | tr -d '\n'); \
	D_ACCOUNT=$$(printf '%s' "ACCOUNT_ID=$${ACCOUNT_ID:-}" | base64 | tr -d '\n'); \
	DART_DEFINES="$$D_MOCKED,$$D_FLAVOR,$$D_ACCOUNT"; \
	export DART_DEFINES; \
	$(MAKE) --no-print-directory _build-mocked SCHEME=$(1) DESTINATION="$$DEST"; \
	xcrun simctl boot "$$UDID" 2>/dev/null || true; \
	APP_DIR=$$($(MAKE) --no-print-directory print-build-dir-scheme SCHEME=$(1) DESTINATION="$$DEST"); \
	APP_NAME=$$($(MAKE) --no-print-directory print-product-name-scheme SCHEME=$(1) DESTINATION="$$DEST"); \
	xcrun simctl install "$$UDID" "$$APP_DIR/$$APP_NAME"; \
	if [ "$(2)" = "launch" ]; then \
		open -a Simulator --args -CurrentDeviceUDID "$$UDID"; \
		xcrun simctl launch "$$UDID" net.blocka.app; \
	else \
		echo "installed $$APP_NAME on '$(SIM_NAME)' ($$UDID) — Appium target UDID: $$UDID"; \
	fi
endef

run-six-mocked:               ; @$(call run-mocked-app,Mocked,launch)
run-family-mocked:            ; @$(call run-mocked-app,FamilyMocked,launch)
appium-install-six-mocked:    ; @$(call run-mocked-app,Mocked,install)
appium-install-family-mocked: ; @$(call run-mocked-app,FamilyMocked,install)
