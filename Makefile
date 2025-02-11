# Define common variables 
FASTLANE := fastlane
PUBLISH_AAB := android/app/build/outputs/bundle/familyRelease/app-family-release.aab
PUBLISH_PKG := org.blokada.family
PUBLISH_META := metadata/android-family/
CI_BUILD_DIR := /tmp/build
 
# Default target 
.DEFAULT_GOAL := build
 
.PHONY: clean test build build-android-family build-android-six \
	publish-android unpack-gplay-key clean-gplay-key \
	d-build-android-family dq-deps dq-android \
	dq-ifam qd-isix \
	ci-copy-source ci-build-android-family

 
clean: 
	$(MAKE) clean-gplay-key
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


# Debug build targets for development
d-build-android-family:
	$(MAKE) -C common/ get-deps
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ d-lib-android
	$(MAKE) -C android/ aab-family

d-build-android-six:
	$(MAKE) -C common/ get-deps
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ d-lib-android
	$(MAKE) -C android/ aab-six


# Publish targets
publish-android:
	$(MAKE) unpack-gplay-key
	$(FASTLANE) supply --aab $(PUBLISH_AAB) \
	--package_name "$(PUBLISH_PKG)" \
	--json_key blokada-gplay.json \
	--metadata_path $(PUBLISH_META) \
	--track internal

unpack-gplay-key:
	@if [ -z "$$BLOKADA_GPLAY_KEY_BASE64" ]; then \
	    echo "Error: BLOKADA_GPLAY_KEY_BASE64 is not set. Please export it before running this command."; \
	    exit 1; \
	fi
	@echo "$$BLOKADA_GPLAY_KEY_BASE64" | base64 --decode > blokada-gplay.json

clean-gplay-key:
	rm -rf blokada-gplay.json


# Quick targeted recompilation targets for development
dq-deps:
	$(MAKE) clean
	$(MAKE) -C common/ get-deps

dq-android:
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ d-lib-android

dq-ifam:
	$(MAKE) -C android/ d-install-family

dq-isix:
	$(MAKE) -C android/ d-install-six


# CI-specific targets
ci-copy-source:
	@echo "Copying source files to $(CI_BUILD_DIR)..."
	rm -rf $(CI_BUILD_DIR)
	mkdir -p $(CI_BUILD_DIR)
	cp -r . $(CI_BUILD_DIR)

ci-build-android: ci-copy-source
	@echo "Building in $(CI_BUILD_DIR)..."
	cd $(CI_BUILD_DIR) && $(MAKE) build-android
	cp -r $(CI_BUILD_DIR)/android/app/build ./android/app/

