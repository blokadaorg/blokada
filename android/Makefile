# Define common variables
GRADLE := ./gradlew

# Default target
.DEFAULT_GOAL := build

.PHONY: clean build d-apk-family apk-family d-apk-six apk-six \
	aab-family aab-six wireguard \
	d-install-family d-install-six

clean:
	$(GRADLE) clean


# Build everything from scratch for release and publish
build: aab-family aab-six


# Various build targets (assume prerequisites to be compiled)
aab-family:
	$(GRADLE) bundleFamilyRelease

aab-six:
	$(GRADLE) bundleSixRelease

apk-family:
	$(GRADLE) assembleFamilyRelease

apk-six:
	$(GRADLE) assembleSixRelease


# Development targets
d-apk-family:
	$(GRADLE) assembleFamilyDebug

d-apk-six:
	$(GRADLE) assembleSixDebug

d-install-family:
	$(GRADLE) installFamilyDebug

d-install-six:
	$(GRADLE) installSixDebug

d-uninstall:
	$(GRADLE) uninstallSixDebug uninstallFamilyDebug
