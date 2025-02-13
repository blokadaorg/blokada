# Define common variables
FLUTTER := flutter
PIGEON := ./scripts/pigeon.py
DART := dart
OUTPUT_DIR := build/pigeon/

# Default target
.DEFAULT_GOAL := build

.PHONY: test clean get-deps gen-pigeon-android gen-pigeon-ios gen-build-runner \
	d-lib-android d-lib-ios lib-android lib-ios \
        build-android build-ios build build-web

test:
	$(FLUTTER) test

clean:
	$(FLUTTER) clean


# Build everything from scratch for release and publish
build: get-deps gen-pigeon-android gen-pigeon-ios gen-build-runner test lib-android lib-ios

# Build Android and iOS library with dependencies
build-android: get-deps gen-pigeon-android gen-build-runner lib-android

build-ios: get-deps gen-pigeon-ios gen-build-runner


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
lib-android:
	$(FLUTTER) build aar --no-profile --no-debug --no-pub

lib-ios:
	$(FLUTTER) build ios-framework --no-profile --no-debug --no-pub


# Development targets

d-lib-android:
	$(FLUTTER) build aar --no-profile --no-release --verbose --no-pub

d-lib-ios:
	$(FLUTTER) build ios-framework --no-profile --no-release --verbose --no-pub


# Web build (not used yet)
build-web:
	$(FLUTTER) build web
