# Define common variables 
FLAVOR := family
FASTLANE := fastlane

VERSION_SCRIPT := ./scripts/version.py
ANDROID_PROJECT_FILE := android/app/build.gradle
IOS_PROJECT_FILE := ios/IOS.xcodeproj/project.pbxproj

CI_BUILD_DIR := /tmp/build
 
# Default target 
.DEFAULT_GOAL := build
 
.PHONY: clean test build build-android-family build-android-six \
	publish-android gplay-key-unpack gplay-key-clean \
	publish-ios appstore-key-unpack appstore-key-clean \
	d-build-android-family dq-deps dq-android \
	version version-increment version-clean \
	dq-ifam qd-isix \
	ci-copy-source ci-build-android-family

 
clean: 
	$(MAKE) gplay-key-clean
	$(MAKE) appstore-key-clean
	$(MAKE) -C common/ clean
	$(MAKE) -C android/ clean

test:
	$(MAKE) -C common/ get-deps
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ test


# Build everything from scratch for release and publish
build:
	$(MAKE) -C common/ build
	$(MAKE) -C android/ build


# Various build targets (release)
build-android:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ build

build-android-family:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ aab-family

build-android-six:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ aab-six

build-ios:
	$(MAKE) -C common/ build-ios
	$(MAKE) -C ios/ build

build-ios-family:
	$(MAKE) -C common/ build-ios
	$(MAKE) -C ios/ build-family

build-ios-six:
	$(MAKE) -C common/ build-ios
	$(MAKE) -C ios/ build-six


# Version management targets
version:
	@VERSION_NAME_ARG=$(if $(NAME),$(NAME),$(BLOKADA_VERSION_NAME)); \
	VERSION_CODE_ARG=$(if $(CODE),$(CODE),$(BLOKADA_VERSION_CODE)); \
	$(VERSION_SCRIPT) --android-file $(ANDROID_PROJECT_FILE) \
		--xcodeproj-file $(IOS_PROJECT_FILE) \
		--version-name $$VERSION_NAME_ARG \
		--version-code $$VERSION_CODE_ARG

version-clean:
	git restore $(ANDROID_PROJECT_FILE)
	git restore $(IOS_PROJECT_FILE)


# Publish targets
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

gplay-key-unpack:
	@if [ -z "$$BLOKADA_GPLAY_KEY_BASE64" ]; then \
	    echo "Error: BLOKADA_GPLAY_KEY_BASE64 is not set. Please export it before running this command."; \
	    exit 1; \
	fi
	@echo "$$BLOKADA_GPLAY_KEY_BASE64" | base64 --decode > blokada-gplay.json

gplay-key-clean:
	rm -rf blokada-gplay.json

publish-ios:
	$(MAKE) appstore-key-unpack
	@LANE=$(if $(filter family,$(FLAVOR)),publish_ios_family,publish_ios_six); \
	cd ios/ && $(FASTLANE) $$LANE
	$(MAKE) appstore-key-clean

appstore-key-unpack:
	@if [ -z "$$BLOKADA_APPSTORE_KEY_BASE64" ]; then \
	    echo "Error: BLOKADA_APPSTORE_KEY_BASE64 is not set. Please export it before running this command."; \
	    exit 1; \
	fi
	@echo "$$BLOKADA_APPSTORE_KEY_BASE64" | base64 --decode > blokada-appstore.json

appstore-key-clean:
	rm -rf blokada-appstore.json


# Debug build targets for development
d-build-android-family:
	$(MAKE) -C common/ get-deps
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ d-lib-android
	$(MAKE) -C android/ d-apk-family

d-build-android-six:
	$(MAKE) -C common/ get-deps
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ d-lib-android
	$(MAKE) -C android/ d-apk-six


# Clean and get flutter common deps
dq-deps:
	$(MAKE) clean
	$(MAKE) -C common/ get-deps

# Generate flutter common files for Android
dq-android:
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ d-lib-android

# Generate flutter common files for iOS
dq-ios:
	$(MAKE) -C common/ gen-pigeon-ios
	$(MAKE) -C common/ gen-build-runner

dq-ifam:
	$(MAKE) -C android/ d-install-family

dq-isix:
	$(MAKE) -C android/ d-install-six

# Uninstall all Android apps
dq-u: 
	$(MAKE) -C android/ d-uninstall


# CI-specific targets
ci-copy-source:
	@echo "Copying source files to $(CI_BUILD_DIR)..."
	@rm -rf $(CI_BUILD_DIR)
	@mkdir -p $(CI_BUILD_DIR)
	@cp -r . $(CI_BUILD_DIR)

ci-build-android: ci-copy-source
	cd $(CI_BUILD_DIR) && $(MAKE) version
	cd $(CI_BUILD_DIR) && $(MAKE) build-android
	cp -r $(CI_BUILD_DIR)/android/app/build ./android/app/

ci-build-android-family: ci-copy-source
	cd $(CI_BUILD_DIR) && $(MAKE) version
	cd $(CI_BUILD_DIR) && $(MAKE) build-android-family
	cp -r $(CI_BUILD_DIR)/android/app/build ./android/app/

ci-build-android-six: ci-copy-source
	cd $(CI_BUILD_DIR) && $(MAKE) version
	cd $(CI_BUILD_DIR) && $(MAKE) build-android-six
	cp -r $(CI_BUILD_DIR)/android/app/build ./android/app/

ci-build-ios:
	$(MAKE) version
	$(MAKE) build-ios

ci-build-ios-family:
	$(MAKE) version
	$(MAKE) build-ios-family

ci-build-ios-six:
	$(MAKE) version
	$(MAKE) build-ios-six
