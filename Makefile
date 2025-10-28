# Define common variables 
FLAVOR := family
FASTLANE := fastlane

VERSION_SCRIPT := ./scripts/version.py
ANDROID_PROJECT_FILE := android/app/build.gradle
IOS_PROJECT_FILE := ios/IOS.xcodeproj/project.pbxproj

TRANSLATE_SCRIPT := ./scripts/sync-translations.sh

CI_BUILD_DIR := /tmp/build

ADAPTY_DIR := ~/Downloads
ADAPTY_VER := 3_8.0
 
# Default target 
.DEFAULT_GOAL := build
 
.PHONY: clean test build \
	translate \
	build-android build-android-family build-android-six \
	build-ios build-ios-family build-ios-six build-ios-six-debug \
	version version-clean \
	publish-android gplay-key-unpack gplay-key-clean \
	publish-ios appstore-key-unpack appstore-key-clean fastlane-match \
	build-android-family-debug build-android-six-debug \
	build-android-family-quick build-android-six-quick \
	build-android-family-debug-quick build-android-six-debug-quick \
	gen regen android regen-android regen-ios \
	install-family install-family-debug \
	install-six install-six-debug uninstall \
	ci-copy-source ci-test \
	ci-build-android-family ci-build-android-six \
	ci-build-ios-family ci-build-ios-six \
	adapty-paywalls \
	appium-test \

translate:
	$(TRANSLATE_SCRIPT)

clean: 
	$(MAKE) gplay-key-clean
	$(MAKE) appstore-key-clean
	$(MAKE) -C common/ clean
	$(MAKE) -C android/ clean

test:
	$(MAKE) -C common/ pub gen-android runner
	$(MAKE) -C common/ test

# Build everything from scratch
build:
	$(MAKE) -C common/ build
	$(MAKE) -C android/ build
	$(MAKE) -C ios/ build

# Build all android .aab apps from scratch (release)
build-android:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ build

# Build android family .aab from scratch (release)
build-android-family:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ aab-family

# Build android six .aab from scratch (release)
build-android-six:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ aab-six

# Build all ios .ipa apps from scratch (release)
build-ios:
	$(MAKE) -C common/ build-ios
	$(MAKE) -C ios/ build

# Build ios family .ipa from scratch (release)
build-ios-family:
	$(MAKE) -C common/ build-ios
	$(MAKE) -C ios/ build-family

# Build ios six .ipa from scratch (release)
build-ios-six:
	$(MAKE) -C common/ build-ios
	$(MAKE) -C ios/ build-six

# Build ios six .ipa from scratch (debug)
build-ios-six-debug:
	$(MAKE) -C common/ build-ios
	$(MAKE) -C ios/ build-six-debug


# Run WebdriverIO Appium tests against a connected iOS device
appium-test:
	@set -euo pipefail; \
	cd automation/appium/wdio && \
	npm install >/dev/null 2>&1 && \
	if ! command -v appium >/dev/null 2>&1; then \
		echo "Appium CLI not found. Install with 'npm install -g appium'."; \
		exit 1; \
	fi; \
	node scripts/check-driver.mjs; \
	UDID=$${IOS_UDID:-$$(IOS_AUTO_SELECT_FIRST=1 node scripts/select-device.mjs)} && \
	DEVICE_NAME=$${IOS_DEVICE_NAME:-$$(xcrun devicectl -q list devices --json-output /dev/stdout 2>/dev/null | jq -r ".result.devices[] | select(.hardwareProperties.udid == \"$$UDID\") | .deviceProperties.name" | head -n 1 2>/dev/null)} && \
	export IOS_AUTO_SELECT_FIRST=1; \
	export IOS_UDID="$$UDID"; \
	if [ -n "$$DEVICE_NAME" ]; then \
		export IOS_DEVICE_NAME="$$DEVICE_NAME"; \
	fi; \
	if [ -n "$${APP_BUNDLE_ID:-}" ]; then \
		export APP_BUNDLE_ID="$${APP_BUNDLE_ID}"; \
	fi; \
	$(MAKE) -C ../../../ios appium-install-six IOS_UDID="$$UDID" IOS_DEVICE_NAME="$$DEVICE_NAME"; \
	npx wdio run wdio.conf.ts


# Set version in proper files for all apps (use NAME and CODE params, or env vars)
version:
	@VERSION_NAME_ARG=$(if $(NAME),$(NAME),$(BLOKADA_VERSION_NAME)); \
	VERSION_CODE_ARG=$(if $(CODE),$(CODE),$(BLOKADA_VERSION_CODE)); \
	$(VERSION_SCRIPT) --android-file $(ANDROID_PROJECT_FILE) \
		--xcodeproj-file $(IOS_PROJECT_FILE) \
		--version-name $$VERSION_NAME_ARG \
		--version-code $$VERSION_CODE_ARG

# Restore files changed with version numbers
version-clean:
	git restore $(ANDROID_PROJECT_FILE)
	git restore $(IOS_PROJECT_FILE)


# Publish android app to Google Play internal channel (use FLAVOR param)
publish-android:
	$(MAKE) gplay-key-unpack
	@AAB=$(if $(filter family,$(FLAVOR)),familyRelease/app-family-release.aab,sixRelease/app-six-release.aab); \
	PKG=$(if $(filter family,$(FLAVOR)),org.blokada.family,org.blokada.sex); \
	$(FASTLANE) supply --aab android/app/build/outputs/bundle/$$AAB \
	--package_name "$$PKG" \
	--json_key blokada-gplay.json \
	--metadata_path metadata/android-$(FLAVOR) \
	--track internal
	$(MAKE) gplay-key-clean

# Unpack Google Play api key for publishing (use env var)
gplay-key-unpack:
	@if [ -z "$$BLOKADA_GPLAY_KEY_BASE64" ]; then \
	    echo "Error: BLOKADA_GPLAY_KEY_BASE64 is not set. Please export it before running this command."; \
	    exit 1; \
	fi
	@echo "$$BLOKADA_GPLAY_KEY_BASE64" | base64 --decode > blokada-gplay.json

# Clean up after unpacking Google Play key
gplay-key-clean:
	rm -rf blokada-gplay.json

# Publish ios app to AppStore TestFlight (use FLAVOR param)
publish-ios:
	$(MAKE) appstore-key-unpack
	@LANE=$(if $(filter family,$(FLAVOR)),publish_ios_family,publish_ios_six); \
	cd ios/ && $(FASTLANE) $$LANE
	$(MAKE) appstore-key-clean

# Unpack AppStore api key for publishing (use env var)
appstore-key-unpack:
	@if [ -z "$$BLOKADA_APPSTORE_KEY_BASE64" ]; then \
	    echo "Error: BLOKADA_APPSTORE_KEY_BASE64 is not set. Please export it before running this command."; \
	    exit 1; \
	fi
	@echo "$$BLOKADA_APPSTORE_KEY_BASE64" | base64 --decode > ios/blokada-appstore.json

# Clean up after unpacking AppStore key
appstore-key-clean:
	rm -rf ios/blokada-appstore.json

fastlane-match:
	cd ios/ && $(FASTLANE) match development --force_for_new_devices --include_mac_in_profiles true
	cd ios/ && $(FASTLANE) match appstore --readonly


# Build android family .apk from scratch (debug)
build-android-family-debug: regen-android
	$(MAKE) -C android/ apk-family-debug

# Build android six .apk from scratch (debug)
build-android-six-debug: regen-android
	$(MAKE) -C android/ apk-six-debug

# Quick rebuild android family .apk (assumes flutter is built)
build-android-family-debug-quick:
	@echo "Warning: use quick rebuild targets only if you haven't modified sixcommon"
	$(MAKE) -C android/ apk-family-debug

# Quick rebuild android six .apk (assumes flutter is built)
build-android-six-debug-quick:
	@echo "Warning: use quick rebuild targets only if you haven't modified sixcommon"
	$(MAKE) -C android/ apk-six-debug

# Quick rebuild android family .apk (assumes flutter is built)
build-android-family-quick:
	@echo "Warning: use quick rebuild targets only if you haven't modified sixcommon"
	$(MAKE) -C android/ apk-family

# Quick rebuild android six .apk (assumes flutter is built)
build-android-six-quick:
	@echo "Warning: use quick rebuild targets only if you haven't modified sixcommon"
	$(MAKE) -C android/ apk-six


# Prepare flutter gen files
gen:
	$(MAKE) -C common/ gen

# Clean everything and rebuild flutter gen files
regen:
	$(MAKE) clean
	$(MAKE) -C common/ pub gen

# Rebuild flutter android common lib - no dependencies (debug)
android:
	$(MAKE) -C common/ lib-debug

# Clean everything and rebuild flutter android common lib (debug)
regen-android:
	$(MAKE) -C common/ pub gen-android runner lib-debug

# Clean everything and rebuild flutter ios dependencies
regen-ios:
	$(MAKE) -C common/ build-ios


# Install android family .apk (release)
install-family:
	$(MAKE) -C android/ install-family

# Install android family .apk (debug)
install-family-debug:
	$(MAKE) -C android/ install-family-debug

# Install android six .apk (release)
install-six:
	$(MAKE) -C android/ install-six

# Install android six .apk (debug)
install-six-debug:
	$(MAKE) -C android/ install-six-debug

# Uninstall all Android apps
uninstall: 
	$(MAKE) -C android/ uninstall


# CI: Copy the workspace out of volume to prevent weird filesystem issues
ci-copy-source:
	@echo "Copying source files to $(CI_BUILD_DIR)..."
	@rm -rf $(CI_BUILD_DIR)
	@mkdir -p $(CI_BUILD_DIR)
	@cp -r . $(CI_BUILD_DIR)

# CI: build android family app from scratch
ci-build-android-family:
	$(MAKE) version
	$(MAKE) build-android-family

# CI: build android six app from scratch
ci-build-android-six:
	$(MAKE) version
	$(MAKE) build-android-six

# CI: build ios family app from scratch
ci-build-ios-family:
	$(MAKE) version
	$(MAKE) build-ios-family

# CI: build ios six app from scratch
ci-build-ios-six:
	$(MAKE) version
	$(MAKE) build-ios-six

ci-test:
	$(MAKE) clean
	$(MAKE) test

# Put Adapty fallback paywalls in the right places. uses DIR
adapty-paywalls:
	rm -rf common/assets/fallbacks/*
	rm -rf android/app/src/main/assets/fallbacks/*
	cp $(ADAPTY_DIR)/android_$(ADAPTY_VER)_fallback.json common/assets/fallbacks/android.json
	cp $(ADAPTY_DIR)/ios_$(ADAPTY_VER)_fallback.json common/assets/fallbacks/ios.json
	cp $(ADAPTY_DIR)/android_$(ADAPTY_VER)_fallback.json android/app/src/main/assets/fallbacks/android.json
