# Define common variables
FLUTTER := fvm flutter
PIGEON := ./scripts/pigeon.py
DART := fvm dart
OUTPUT_DIR := build/pigeon/

# Default target
.DEFAULT_GOAL := build

.PHONY: test test-local analyze clean pub pub-verify gen-android gen-ios runner \
	lib lib-debug \
        build-android build-ios build \
	other-lib-ios-debug other-build-web

test:
	$(FLUTTER) test

test-local:
	$(FLUTTER) test --no-pub

analyze:
	$(FLUTTER) analyze

clean:
	$(FLUTTER) clean


# Build everything from scratch (release)
build: pub gen-android gen-ios runner lib

# Build the Android library from scratch (release)
build-android: pub gen-android runner lib

# Build the add-to-app iOS frameworks the host Xcode project links and embeds.
# Produces Flutter/App/FlutterPluginRegistrant and one xcframework per plugin
# under build/ios-framework/<config>/; the host picks <config> via
# $(CONFIGURATION). precache first so a freshly installed SDK on CI has the iOS
# engine artifacts. Replaces the old CocoaPods integration.
# --no-codesign: Flutter 3.44 added native XCFramework signing to `build
# ios-framework` and defaults it ON, which breaks whenever a machine holds more
# than one identity for the team ("Multiple identities found for development
# team ..."). We already sign these ourselves in `sign-ios-frameworks` (the
# ITMS-91065 fix), so opt out and keep the pre-3.44 behaviour: Flutter emits
# unsigned xcframeworks, our script signs them for release. Flutter's own
# --codesign-identity is a candidate to replace that script later; not here.
build-ios: pub gen-ios runner
	$(FLUTTER) precache --ios
	$(FLUTTER) build ios-framework --output=build/ios-framework --no-profile --no-codesign

# Fetch dependencies from pubspec.yaml (flutter pub get)
pub:
	$(FLUTTER) pub get

# Fail if the committed pubspec.lock is not a valid resolution under the pinned
# Flutter. Plain `pub get` silently re-resolves and rewrites the lock instead, so
# a lock generated on a different SDK (Dependabot's) otherwise lands unnoticed
# and CI goes green against dependencies nobody committed. Pure check: it never
# rewrites the lock.
pub-verify:
	$(FLUTTER) pub get --enforce-lockfile

# Generate all necessary files for both platforms
gen: gen-android gen-ios runner

# Generate platform interface files for Android
gen-android:
	$(PIGEON) --android --output=$(OUTPUT_DIR) --cmd="$(DART)"

# Generate platform interface files for iOS
gen-ios:
	$(PIGEON) --output=$(OUTPUT_DIR) --cmd="$(DART)"

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
	$(FLUTTER) build ios-framework --no-profile --no-release --verbose --no-pub --no-codesign

# Build web (not used yet)
other-build-web:
	$(FLUTTER) build web
