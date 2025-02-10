# Define common variables 
FASTLANE := fastlane
PUBLISH_AAB := android/app/build/outputs/bundle/familyRelease/app-family-release.aab
PUBLISH_PKG := org.blokada.family
CI_BUILD_DIR := /tmp/build
 
# Default target 
.DEFAULT_GOAL := build
 
.PHONY: clean build
 
clean: 
	$(MAKE) clean-gplay-key
	$(MAKE) -C common/ clean
	$(MAKE) -C android/ clean


# Build everything from scratch for release and publish
build:
	$(MAKE) -C common/ build
	$(MAKE) -C android/ build


# Various build targets (release)
build-android-family:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ aab-family

build-android-v6:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ aab-v6


# Debug build targets for development
d-build-android-family:
	$(MAKE) -C common/ get-deps
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ d-lib-android
	$(MAKE) -C android/ aab-family


# Publish targets
publish-android:
	$(MAKE) unpack-gplay-key
	$(FASTLANE) supply --aab $(PUBLISH_AAB) \
	--package_name "$(PUBLISH_PKG)" \
	--json_key blokada-gplay.json \
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
	@echo "Copying source files to $(BUILD_DIR)..."
	@rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
	@cp -r . $(BUILD_DIR)

ci-build-android-family: ci-copy-source
	@echo "Building in $(BUILD_DIR)..."
	@cd $(BUILD_DIR) && $(MAKE) build-android-family


# OLD to be removed

sixcommon:
	@if test -d "six-common"; then \
		if test ! -d "app/six-common" || test "six-common" -nt "app/six-common/marker"; then \
			echo "Building six-common..."; \
			cd six-common && make get gen && cd ../ ; \
			cd six-common && flutter build aar --no-profile && cd ../ ; \
			mkdir -p app/six-common; \
			cp -r six-common/build/host/outputs/repo app/six-common; \
			touch app/six-common/marker; \
		fi \
	fi

