# Define common variables
BUNDLE := bundle
BUNDLE_EXEC := $(BUNDLE) exec

FASTLANE := $(BUNDLE_EXEC) fastlane
POD := $(BUNDLE_EXEC) pod
XCODEBUILD := xcodebuild
XCODE_WORKSPACE := IOS.xcworkspace
CHECK_SCHEME ?= Dev
CHECK_CONFIG ?= Debug

# Make shell exit on any command failure
.SHELLFLAGS := -ec

# Default target
.DEFAULT_GOAL := build

.PHONY: build build-family build-six build-six-debug build-family-debug \
	ipa-family ipa-six pods check run-six run-family appium-install-six appium-install-family \
	print-build-dir-six print-build-dir-family

# Note: for all targets in this Makefile, the common lib has to be
# ready beforehand. This is handled when running make targets from
# the root directory instead.

include make/run-helpers.mk


# Build everything from scratch (release)
build:
	export LANG=en_US.UTF-8
	$(BUNDLE) check || $(BUNDLE) install
	$(POD) repo update
	$(POD) install --repo-update
	$(MAKE) ipa-family
	$(MAKE) ipa-six

# Build .ipa of family (release) - with pods
build-family:
	export LANG=en_US.UTF-8
	$(BUNDLE) check || $(BUNDLE) install
	$(POD) repo update
	$(POD) install --repo-update
	$(MAKE) ipa-family

# Build .ipa of six (release) - with pods
build-six:
	export LANG=en_US.UTF-8
	$(BUNDLE) check || $(BUNDLE) install
	$(POD) repo update
	$(POD) install --repo-update
	$(MAKE) ipa-six

# Build .ipa of family (release)
ipa-family:
	$(BUNDLE) check || $(BUNDLE) install
	$(FASTLANE) build_ios_family

# Build .ipa of six (release)
ipa-six:
	$(MAKE) -C BlockaWebExtension gen-rules
	$(BUNDLE) check || $(BUNDLE) install
	$(FASTLANE) build_ios_six

# Build .ipa of six - configurable configuration (defaults to Debug, overridden by CONFIG parameter)
build-six-debug:
	@$(MAKE) --no-print-directory -s -C BlockaWebExtension gen-rules
	$(call xcode-build,build,Dev,$(if $(CONFIG),$(CONFIG),Debug),$(DESTINATION),)

# Build .ipa of family - configurable configuration (defaults to Debug, overridden by CONFIG parameter)
build-family-debug:
	$(MAKE) -C BlockaWebExtension gen-rules
	$(call xcode-build,build,FamilyDev,$(if $(CONFIG),$(CONFIG),Debug),$(DESTINATION),)

print-build-dir-six:
	@$(call xcode-build-dir,Dev,$(if $(CONFIG),$(CONFIG),Debug),$(DESTINATION))

print-build-dir-family:
	@$(call xcode-build-dir,FamilyDev,$(if $(CONFIG),$(CONFIG),Debug),$(DESTINATION))

# Regenerate Podfile.lock
pods:
	rm -rf Podfile.lock
	$(BUNDLE) check || $(BUNDLE) install
	$(POD) install --repo-update

# Compile the iOS app without launching it, to catch broken imports,
# generated bindings, and signature mismatches.
# Usage: make check [CHECK_SCHEME="Dev"] [CHECK_CONFIG="Debug"]
check:
	$(BUNDLE) check || $(BUNDLE) install
	$(call xcode-build,build,$(CHECK_SCHEME),$(CHECK_CONFIG),generic/platform=iOS Simulator,CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES)

# Build, install and run six flavor on an auto-selected physical iPhone/iPad.
# Usage: make run-six [IOS_DEVICE_NAME="device name"] [CONFIG="Release|Debug"]
# Default: uses the first paired iPhone/iPad when IOS_DEVICE_NAME is not provided.
# Default config: Release (required for iOS 14+ to launch without Xcode/Flutter tooling connection)
run-six:
	$(call run-app,Dev,Dev.app,net.blocka.app,build-six-debug,print-build-dir-six,launch,no,$(if $(CONFIG),$(CONFIG),Release))

# Build, install and run family flavor on an auto-selected physical iPhone/iPad.
# Usage: make run-family [IOS_DEVICE_NAME="device name"] [CONFIG="Release|Debug"]
# Default: uses the first paired iPhone/iPad when IOS_DEVICE_NAME is not provided.
# Default config: Release (required for iOS 14+ to launch without Xcode/Flutter tooling connection)
run-family:
	$(call run-app,FamilyDev,FamilyDev.app,net.blocka.app.family,build-family-debug,print-build-dir-family,launch,no,$(if $(CONFIG),$(CONFIG),Release))

# Build and install the six flavor on a physical device without launching, primed for Appium runs.
# Usage: make appium-install-six [IOS_DEVICE_NAME="device name"] [CONFIG="Release|Debug"]
appium-install-six:
	$(call run-app,Dev,Dev.app,net.blocka.app,build-six-debug,print-build-dir-six,install,no,$(if $(CONFIG),$(CONFIG),Release))

# Build and install the family flavor on a physical device without launching, primed for Appium runs.
# Usage: make appium-install-family [IOS_DEVICE_NAME="device name"] [CONFIG="Release|Debug"]
appium-install-family:
	$(call run-app,FamilyDev,FamilyDev.app,net.blocka.app.family,build-family-debug,print-build-dir-family,install,no,$(if $(CONFIG),$(CONFIG),Release))
