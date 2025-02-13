# Define common variables
FASTLANE := fastlane

# Default target
.DEFAULT_GOAL := build

.PHONY: build build-family build-six ipa-family ipa-six

# Note: for all targets in this Makefile, the common lib has to be
# ready beforehand. This is handled when running make targets from
# the root directory instead.


# Build everything from scratch (release)
build:
	pod install
	$(MAKE) ipa-family
	$(MAKE) ipa-six

# Build .ipa of family (release) - with pods
build-family:
	pod install
	$(MAKE) ipa-family

# Build .ipa of six (release) - with pods
build-six:
	pod install
	$(MAKE) ipa-six

# Build .ipa of family (release)
ipa-family:
	$(FASTLANE) build_ios_family

# Build .ipa of six (release)
ipa-six:
	$(FASTLANE) build_ios_six
