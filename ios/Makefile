# Define common variables
FASTLANE := fastlane

# Make shell exit on any command failure
.SHELLFLAGS := -ec

# Default target
.DEFAULT_GOAL := build

.PHONY: build build-family build-six build-six-debug build-family-debug ipa-family ipa-six pods run-six run-family appium-install-six

# Note: for all targets in this Makefile, the common lib has to be
# ready beforehand. This is handled when running make targets from
# the root directory instead.


# Build everything from scratch (release)
build:
	export LANG=en_US.UTF-8
	pod repo update
	pod install --repo-update
	$(MAKE) ipa-family
	$(MAKE) ipa-six

# Build .ipa of family (release) - with pods
build-family:
	export LANG=en_US.UTF-8
	pod repo update
	pod install --repo-update
	$(MAKE) ipa-family

# Build .ipa of six (release) - with pods
build-six:
	export LANG=en_US.UTF-8
	pod repo update
	pod install --repo-update
	$(MAKE) ipa-six

# Build .ipa of family (release)
ipa-family:
	$(FASTLANE) build_ios_family

# Build .ipa of six (release)
ipa-six:
	$(MAKE) -C BlockaWebExtension gen-rules
	$(FASTLANE) build_ios_six

# Build .ipa of six - configurable configuration (defaults to Debug, overridden by CONFIG parameter)
build-six-debug:
	$(MAKE) -C BlockaWebExtension gen-rules
	xcodebuild -workspace IOS.xcworkspace -scheme Dev -configuration $(or $(CONFIG),Debug) build

# Build .ipa of family - configurable configuration (defaults to Debug, overridden by CONFIG parameter)
build-family-debug:
	$(MAKE) -C BlockaWebExtension gen-rules
	xcodebuild -workspace IOS.xcworkspace -scheme FamilyDev -configuration $(or $(CONFIG),Debug) build

# Regenerate Podfile.lock
pods:
	rm -rf Podfile.lock
	pod install --repo-update

# Build, install and run six flavor on connected device with console output
# Usage: make run-six [DEVICE_NAME="device name"] [CONFIG="Release|Debug"]
# Default: CONFIG=Release (required for iOS 14+ to launch without Xcode/Flutter tooling connection)
run-six: CONFIG?=Release
run-six: build-six-debug
	$(call deploy-app,Dev,Dev.app,net.blocka.app,launch,$(DEVICE_NAME))

# Build, install and run family flavor on connected device with console output
# Usage: make run-family [DEVICE_NAME="device name"] [CONFIG="Release|Debug"]
# Default: CONFIG=Release (required for iOS 14+ to launch without Xcode/Flutter tooling connection)
run-family: CONFIG?=Release
run-family: build-family-debug
	$(call deploy-app,FamilyDev,FamilyDev.app,net.blocka.app.family,launch,$(DEVICE_NAME))

# Build and install the six flavor without launching, primed for Appium runs
appium-install-six: CONFIG?=Release
appium-install-six: build-six-debug
	$(call deploy-app,Dev,Dev.app,net.blocka.app,install,)

# Shared function to discover device, install the app, and optionally launch it.
# Usage: $(call deploy-app,SCHEME,APP_NAME,BUNDLE_ID,install|launch,REQUESTED_NAME)
define deploy-app
	@set -euo pipefail; \
	DEVICES_JSON=$$(xcrun devicectl -q list devices --json-output /dev/stdout 2>&1 | sed '/ERROR:/,$$d'); \
	REQUESTED_NAME="$${IOS_DEVICE_NAME:-$(strip $(5))}"; \
	DEVICE_UDID="$${IOS_UDID:-}"; \
	if [ -z "$$DEVICE_UDID" ]; then \
		if [ -n "$$REQUESTED_NAME" ]; then \
			DEVICE_UDID=$$(echo "$$DEVICES_JSON" | jq -r ".result.devices[] | select(.deviceProperties.name == \"$$REQUESTED_NAME\" and .hardwareProperties.platform == \"iOS\" and .connectionProperties.pairingState == \"paired\") | .hardwareProperties.udid" | head -n 1 2>/dev/null); \
		else \
			DEVICE_UDID=$$(echo "$$DEVICES_JSON" | jq -r '.result.devices[] | select((.hardwareProperties.deviceType == "iPhone" or .hardwareProperties.deviceType == "iPad") and .connectionProperties.pairingState == "paired") | .hardwareProperties.udid' | head -n 1 2>/dev/null); \
		fi; \
	fi; \
	DEVICE_IDENTIFIER=$$(echo "$$DEVICES_JSON" | jq -r ".result.devices[] | select(.hardwareProperties.udid == \"$$DEVICE_UDID\") | .identifier" | head -n 1 2>/dev/null); \
	DEVICE_NAME_FOUND=$$(echo "$$DEVICES_JSON" | jq -r ".result.devices[] | select(.hardwareProperties.udid == \"$$DEVICE_UDID\") | .deviceProperties.name" 2>/dev/null); \
	if [ -z "$$DEVICE_UDID" ] || [ -z "$$DEVICE_IDENTIFIER" ]; then \
		echo "Error: No device found. Available devices:"; \
		echo "$$DEVICES_JSON" | jq -r '.result.devices[] | select(.hardwareProperties.platform == "iOS" and .connectionProperties.pairingState == "paired") | "  \(.deviceProperties.name) (\(.hardwareProperties.deviceType))"' 2>/dev/null || echo "  (none found)"; \
		exit 1; \
	fi; \
	if [ -z "$$DEVICE_NAME_FOUND" ]; then \
		DEVICE_NAME_FOUND=$$DEVICE_UDID; \
	fi; \
	echo "📱 Target device: $$DEVICE_NAME_FOUND"; \
	APP_DIR=$$(xcodebuild -workspace IOS.xcworkspace -scheme $(1) -configuration $(CONFIG) -showBuildSettings | awk -F'= ' '/CONFIGURATION_BUILD_DIR/{print $$2; exit}'); \
	echo "🧹 Removing existing installation (if any)..."; \
	xcrun devicectl device uninstall app --device $$DEVICE_IDENTIFIER $(3) >/dev/null 2>&1 || true; \
	echo "📦 Installing $(2) to $$DEVICE_NAME_FOUND"; \
	xcrun devicectl device install app --device $$DEVICE_IDENTIFIER "$$APP_DIR/$(2)"; \
	if [ "$(4)" = "launch" ]; then \
		echo "🚀 Launching $(3)"; \
		xcrun devicectl device process launch --device $$DEVICE_UDID --terminate-existing --console $(3); \
	fi
endef
