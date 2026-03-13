define xcode-build
	$(XCODEBUILD) $(strip $(1)) -workspace $(XCODE_WORKSPACE) -scheme $(strip $(2)) -configuration $(strip $(3)) $(if $(strip $(4)),-destination '$(strip $(4))') $(strip $(5))
endef

define xcode-build-dir
$(XCODEBUILD) -workspace $(XCODE_WORKSPACE) -scheme $(strip $(1)) -configuration $(strip $(2)) $(if $(strip $(3)),-destination '$(strip $(3))') -showBuildSettings | awk -F'= ' '/CONFIGURATION_BUILD_DIR/{print $$2; exit}'
endef

# Shared function to resolve a destination, build for it, and launch or install.
# Usage: $(call run-app,SCHEME,APP_NAME,BUNDLE_ID,BUILD_TARGET,BUILD_DIR_TARGET,launch|install,PREFER_MAC,CONFIG)
define run-app
	@set -euo pipefail; \
	SCHEME="$(1)"; \
	APP_NAME="$(2)"; \
	BUNDLE_ID="$(3)"; \
	BUILD_TARGET="$(4)"; \
	BUILD_DIR_TARGET="$(5)"; \
	ACTION="$(6)"; \
	PREFER_MAC="$(7)"; \
	RUN_CONFIG="$(8)"; \
	SHOW_DESTINATIONS=$$($(XCODEBUILD) -workspace $(XCODE_WORKSPACE) -scheme "$$SCHEME" -showdestinations 2>/dev/null); \
	DEVICES_JSON=$$(xcrun devicectl -q list devices --json-output /dev/stdout 2>&1 | sed '/ERROR:/,$$d'); \
	REQUESTED_NAME="$${IOS_DEVICE_NAME:-}"; \
	DEVICE_UDID="$${IOS_UDID:-}"; \
	DESTINATION_KIND=""; \
	DESTINATION=""; \
	DEVICE_IDENTIFIER=""; \
	DEVICE_NAME_FOUND=""; \
	if [ -n "$$REQUESTED_NAME" ] || [ -n "$$DEVICE_UDID" ]; then \
		DESTINATION_KIND="ios-device"; \
	elif [ "$$PREFER_MAC" = "yes" ]; then \
		MAC_ID=$$(printf '%s\n' "$$SHOW_DESTINATIONS" | sed -n 's/.*platform:macOS.*variant:Designed for \[iPad,iPhone\].*id:\([^,}]*\).*/\1/p' | head -n 1); \
		if [ -n "$$MAC_ID" ]; then \
			DESTINATION_KIND="mac-compat"; \
			DESTINATION="id=$$MAC_ID"; \
		fi; \
	fi; \
	if [ "$$DESTINATION_KIND" != "mac-compat" ] && [ -z "$$DEVICE_UDID" ]; then \
		if [ -n "$$REQUESTED_NAME" ]; then \
			DEVICE_UDID=$$(echo "$$DEVICES_JSON" | jq -r ".result.devices[] | select(.deviceProperties.name == \"$$REQUESTED_NAME\" and .hardwareProperties.platform == \"iOS\" and .connectionProperties.pairingState == \"paired\") | .hardwareProperties.udid" | head -n 1 2>/dev/null); \
		else \
			DEVICE_UDID=$$(echo "$$DEVICES_JSON" | jq -r '.result.devices[] | select((.hardwareProperties.deviceType == "iPhone" or .hardwareProperties.deviceType == "iPad") and .connectionProperties.pairingState == "paired") | .hardwareProperties.udid' | head -n 1 2>/dev/null); \
		fi; \
	fi; \
	if [ "$$DESTINATION_KIND" != "mac-compat" ]; then \
		DEVICE_IDENTIFIER=$$(echo "$$DEVICES_JSON" | jq -r ".result.devices[] | select(.hardwareProperties.udid == \"$$DEVICE_UDID\") | .identifier" | head -n 1 2>/dev/null); \
		DEVICE_NAME_FOUND=$$(echo "$$DEVICES_JSON" | jq -r ".result.devices[] | select(.hardwareProperties.udid == \"$$DEVICE_UDID\") | .deviceProperties.name" | head -n 1 2>/dev/null); \
		if [ -z "$$DEVICE_UDID" ] || [ -z "$$DEVICE_IDENTIFIER" ]; then \
			if [ -n "$$REQUESTED_NAME" ] || [ -n "$${IOS_UDID:-}" ]; then \
				echo "Error: Requested iOS device not found or not paired."; \
			else \
				echo "Error: No runnable target found."; \
			fi; \
			MAC_TARGET=$$(printf '%s\n' "$$SHOW_DESTINATIONS" | sed -n 's/.*platform:macOS.*variant:Designed for \[iPad,iPhone\].*name:\([^}]*\).*/  \1 (Designed for iPad\/iPhone)/p' | head -n 1); \
			echo "Available targets:"; \
			if [ -n "$$MAC_TARGET" ]; then echo "$$MAC_TARGET"; else echo "  (no Mac compatibility target)"; fi; \
			echo "$$DEVICES_JSON" | jq -r '.result.devices[] | select(.hardwareProperties.platform == "iOS" and .connectionProperties.pairingState == "paired") | "  \(.deviceProperties.name) (\(.hardwareProperties.deviceType))"' 2>/dev/null || echo "  (no paired iOS devices)"; \
			exit 1; \
		fi; \
		DESTINATION_KIND="ios-device"; \
		DESTINATION="id=$$DEVICE_UDID"; \
		if [ -z "$$DEVICE_NAME_FOUND" ]; then \
			DEVICE_NAME_FOUND=$$DEVICE_UDID; \
		fi; \
	fi; \
	if [ "$$DESTINATION_KIND" = "mac-compat" ]; then \
		echo "💻 Target: My Mac (Designed for iPad)"; \
	else \
		echo "📱 Target device: $$DEVICE_NAME_FOUND"; \
	fi; \
	$(MAKE) --no-print-directory "$$BUILD_TARGET" CONFIG="$$RUN_CONFIG" DESTINATION="$$DESTINATION"; \
	APP_DIR=$$($(MAKE) --no-print-directory "$$BUILD_DIR_TARGET" CONFIG="$$RUN_CONFIG" DESTINATION="$$DESTINATION"); \
	if [ "$$DESTINATION_KIND" = "mac-compat" ]; then \
		if [ "$$ACTION" = "launch" ]; then \
			echo "🚀 Opening $$APP_NAME"; \
			open "$$APP_DIR/$$APP_NAME"; \
		else \
			echo "Error: install action is only supported for physical iOS devices."; \
			exit 1; \
		fi; \
	else \
		echo "🧹 Removing existing installation (if any)..."; \
		xcrun devicectl device uninstall app --device $$DEVICE_IDENTIFIER "$$BUNDLE_ID" >/dev/null 2>&1 || true; \
		echo "📦 Installing $$APP_NAME to $$DEVICE_NAME_FOUND"; \
		xcrun devicectl device install app --device $$DEVICE_IDENTIFIER "$$APP_DIR/$$APP_NAME"; \
		if [ "$$ACTION" = "launch" ]; then \
			echo "🚀 Launching $$BUNDLE_ID"; \
			xcrun devicectl device process launch --device $$DEVICE_UDID --terminate-existing --console "$$BUNDLE_ID"; \
		fi; \
	fi
endef
