# Define common variables
FASTLANE := fastlane

# Default target
.DEFAULT_GOAL := build

.PHONY: build build-family build-six ipa-family ipa-six


# Build everything from scratch for release and publish
build:
	pod install
	$(MAKE) ipa-family
	$(MAKE) ipa-six

build-family:
	pod install
	$(MAKE) ipa-family

build-six:
	pod install
	$(MAKE) ipa-six


# Various build targets (assume prerequisites to be compiled)
ipa-family:
	$(FASTLANE) build_ios_family

ipa-six:
	$(FASTLANE) build_ios_six
