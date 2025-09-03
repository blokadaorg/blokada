# Define common variables
FASTLANE := fastlane

# Make shell exit on any command failure
.SHELLFLAGS := -ec

# Default target
.DEFAULT_GOAL := build

.PHONY: build build-family build-six build-six-debug build-family-debug ipa-family ipa-six pods run-six run-family

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
	$(call install-and-launch,Dev,Dev.app,net.blocka.app)

# Build, install and run family flavor on connected device with console output
# Usage: make run-family [DEVICE_NAME="device name"] [CONFIG="Release|Debug"]
# Default: CONFIG=Release (required for iOS 14+ to launch without Xcode/Flutter tooling connection)
run-family: CONFIG?=Release
run-family: build-family-debug
	$(call install-and-launch,FamilyDev,FamilyDev.app,net.blocka.app.family)

# Shared function to discover device and install/launch app
# Usage: $(call install-and-launch,SCHEME,APP_NAME,BUNDLE_ID)
define install-and-launch
	@DEVICES_JSON=$$(xcrun devicectl -q list devices --json-output /dev/stdout 2>&1 | sed '/ERROR:/,$$d'); \
	if [ -n "$(DEVICE_NAME)" ]; then \
		DEVICE_UDID=$$(echo "$$DEVICES_JSON" | jq -r ".result.devices[] | select(.deviceProperties.name == \"$(DEVICE_NAME)\" and .hardwareProperties.platform == \"iOS\" and .connectionProperties.pairingState == \"paired\") | .hardwareProperties.udid" | head -n 1 2>/dev/null); \
		DEVICE_NAME_FOUND="$(DEVICE_NAME)"; \
	else \
		DEVICE_UDID=$$(echo "$$DEVICES_JSON" | jq -r '.result.devices[] | select(.hardwareProperties.deviceType == "iPhone" and .connectionProperties.pairingState == "paired") | .hardwareProperties.udid' | head -n 1 2>/dev/null); \
		DEVICE_NAME_FOUND=$$(echo "$$DEVICES_JSON" | jq -r ".result.devices[] | select(.hardwareProperties.udid == \"$$DEVICE_UDID\") | .deviceProperties.name" 2>/dev/null); \
	fi; \
	if [ -z "$$DEVICE_UDID" ]; then \
		echo "Error: No device found. Available devices:"; \
		echo "$$DEVICES_JSON" | jq -r '.result.devices[] | select(.hardwareProperties.platform == "iOS" and .connectionProperties.pairingState == "paired") | "  \(.deviceProperties.name) (\(.hardwareProperties.deviceType))"' 2>/dev/null || echo "  (none found)"; \
		exit 1; \
	fi; \
	echo "📱 Found device: $$DEVICE_NAME_FOUND"; \
	APP_DIR=$$(xcodebuild -workspace IOS.xcworkspace -scheme $(1) -configuration $(CONFIG) -showBuildSettings | awk -F'= ' '/CONFIGURATION_BUILD_DIR/{print $$2; exit}'); \
	echo "📦 Installing and launching..."; \
	xcrun devicectl device install app --device $$DEVICE_UDID "$$APP_DIR/$(2)" && \
	xcrun devicectl device process launch --device $$DEVICE_UDID --terminate-existing --console $(3)
endef
