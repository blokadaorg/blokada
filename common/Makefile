# Define common variables
FLUTTER := flutter
PIGEON := ./scripts/pigeon.py
DART := dart
OUTPUT_DIR := build/

# Default target
.DEFAULT_GOAL := build-ci

.PHONY: test clean get-deps gen-pigeon-android gen-pigeon-ios gen-build-runner \
	lib-android-debug lib-ios-debug lib-android-release lib-ios-release \
        build-android-lib build-ios-lib build-ci build-web

test:
	$(FLUTTER) test

clean:
	$(FLUTTER) clean


# Dependency installation
get-deps:
	$(FLUTTER) pub get

# Code generation
gen-pigeon-android:
	$(PIGEON) --android --output=$(OUTPUT_DIR) --cmd=$(DART)

gen-pigeon-ios:
	$(PIGEON) --output=$(OUTPUT_DIR) --cmd=$(DART)

gen-build-runner:
	$(DART) run build_runner build --delete-conflicting-outputs


# Android and iOS builds
lib-android-debug:
	$(FLUTTER) build aar --no-profile --no-release

lib-ios-debug:
	$(FLUTTER) build ios-framework --no-profile --no-release

lib-android-release:
	$(FLUTTER) build aar --no-profile --no-debug

lib-ios-release:
	$(FLUTTER) build ios-framework --no-profile --no-debug


# Build Android and iOS library with dependencies
build-android-lib: get-deps gen-build-runner gen-pigeon-android lib-android-release

build-ios-lib: get-deps gen-build-runner gen-pigeon-ios lib-ios-release

# Build everything in CI
build-ci: get-deps gen-pigeon-android gen-pigeon-ios gen-build-runner test \
lib-android-release lib-ios-release


# Web build (not used yet)
build-web:
	$(FLUTTER) build web
