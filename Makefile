# Define common variables 
FLAVOR := family
FASTLANE := fastlane

VERSION_SCRIPT := ./scripts/version.py
ANDROID_PROJECT_FILE := android/app/build.gradle
IOS_PROJECT_FILE := ios/IOS.xcodeproj/project.pbxproj

TRANSLATE_SCRIPT := ./scripts/sync-translations.sh

CI_BUILD_DIR := /tmp/build
 
# Default target 
.DEFAULT_GOAL := build
 
.PHONY: clean test build \
	translate \
	build-android build-android-family build-android-six \
	build-ios build-ios-family build-ios-six \
	version version-clean \
	publish-android gplay-key-unpack gplay-key-clean \
	publish-ios appstore-key-unpack appstore-key-clean \
	build-android-family-debug build-android-six-debug \
	rebuild-android-family-debug rebuild-android-six-debug \
	gen regen android regen-android regen-ios \
	install-family install-family-debug \
	install-six install-six-debug uninstall \
	ci-copy-source \
	ci-build-android-family ci-build-android-six \
	ci-build-ios-family ci-build-ios-six \

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


# Build android family .apk from scratch (debug)
build-android-family-debug: regen-android
	$(MAKE) -C android/ apk-family-debug

# Build android six .apk from scratch (debug)
build-android-six-debug: regen-android
	$(MAKE) -C android/ apk-six-debug

# Quick rebuild android family .apk (assumes flutter is built)
rebuild-android-family-debug:
	@echo "Warning: use quick rebuild targets only if you haven't modified sixcommon"
	$(MAKE) -C android/ apk-family-debug

# Quick rebuild android six .apk (assumes flutter is built)
rebuild-android-six-debug:
	@echo "Warning: use quick rebuild targets only if you haven't modified sixcommon"
	$(MAKE) -C android/ apk-six-debug


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
