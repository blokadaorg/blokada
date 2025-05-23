# Define common variables
GRADLE := ./gradlew
GRADLE_OFFLINE := ./gradlew --offline

# Default target
.DEFAULT_GOAL := build

.PHONY: clean build aab-family aab-six aab-six-offline apk-family apk-six \
	apk-family-debug apk-six-debug \
	install-family install-family-debug \
	install-six install-six-debug uninstall

clean:
	$(GRADLE) clean

# Note: for all targets in this Makefile, the common lib has to be
# ready beforehand. This is handled when running make targets from
# the root directory instead.


# Build everything from scratch (release)
build: aab-family aab-six

# Build .aab of family (release)
aab-family:
	$(GRADLE) bundleFamilyRelease

# Build .aab of six (release)
aab-six:
	$(GRADLE) bundleSixRelease

# Build .aab of six (release) using local dependencies
aab-six-offline:
	$(GRADLE_OFFLINE) bundleSixRelease

# Build .apk of family (release)
apk-family:
	$(GRADLE) assembleFamilyRelease

# Build .apk of six (release)
apk-six:
	$(GRADLE) assembleSixRelease

# Build .apk of family (debug)
apk-family-debug:
	$(GRADLE) assembleFamilyDebug

# Build .apk of six (debug)
apk-six-debug:
	$(GRADLE) assembleSixDebug

# Install family (release)
install-family:
	$(GRADLE) installFamilyRelease

# Install family (debug)
install-family-debug:
	$(GRADLE) installFamilyDebug

# Install six (release)
install-six:
	$(GRADLE) installSixRelease

# Install six (debug)
install-six-debug:
	$(GRADLE) installSixDebug

# Uninstall all builds
uninstall:
	$(GRADLE) uninstallSixDebug uninstallFamilyDebug
