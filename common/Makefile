# Define common variables
FLUTTER := flutter
PIGEON := ./scripts/pigeon.py
DART := dart
OUTPUT_DIR := build/pigeon/

# Default target
.DEFAULT_GOAL := build

.PHONY: test clean pub pub-offline gen-android gen-ios runner \
        lib lib-debug \
        build-android build-android-offline build-ios build build-offline \
        other-lib-ios-debug other-build-web

test:
	$(FLUTTER) test

clean:
	$(FLUTTER) clean


# Build everything from scratch (release)
build: pub gen-android gen-ios runner lib

# Build everything from scratch using only local dependencies
build-offline: pub-offline gen-android gen-ios runner lib

# Build the Android library from scratch (release)
build-android: pub gen-android runner lib

# Build the Android library from scratch using local dependencies
build-android-offline: pub-offline gen-android runner lib

# Build iOS dependencies (library itself is built by xcode)
build-ios: pub gen-ios runner

# Fetch dependencies from pubspec.yaml (flutter pub get)
pub:
	$(FLUTTER) pub get

# Fetch dependencies from local cache only
pub-offline:
	$(FLUTTER) pub get --offline

# Generate all necessary files for both platforms
gen: gen-android gen-ios runner

# Generate platform interface files for Android
gen-android:
	$(PIGEON) --android --output=$(OUTPUT_DIR) --cmd=$(DART)

# Generate platform interface files for iOS
gen-ios:
	$(PIGEON) --output=$(OUTPUT_DIR) --cmd=$(DART)

# Generate files from build_runner (mocks etc)
runner:
	$(DART) run build_runner build --delete-conflicting-outputs

# Build the Android library (release)
lib:
	$(FLUTTER) build aar --no-profile --no-debug --no-pub

# Build the Android library (debug)
lib-debug:
	$(FLUTTER) build aar --no-profile --no-release --verbose --no-pub

# Build the iOS library (debug) - only for special cases
other-lib-ios-debug:
	$(FLUTTER) build ios-framework --no-profile --no-release --verbose --no-pub

# Build web (not used yet)
other-build-web:
	$(FLUTTER) build web
