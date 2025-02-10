# Define common variables
GRADLE := ./gradlew

# Default target
.DEFAULT_GOAL := build

.PHONY: clean build d-apk-family apk-family d-apk-six apk-six \
	aab-family aab-six wireguard \
	d-install-family d-install-six

clean:
	rm -rf app/wireguard-android/lib; \
	$(GRADLE) clean; \
	cd wireguard-android && ./gradlew clean && cd ../


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


wireguard:
	@if test -d "wireguard-android"; then \
		if test ! -d "app/wireguard-android/lib" || test "wireguard-android" -nt "app/wireguard-android/lib/marker"; then \
			echo "Building wireguard-android..."; \
			cd wireguard-android && ./gradlew tunnel:build && cd ../ ; \
			mkdir -p app/wireguard-android/lib; \
			cp wireguard-android/tunnel/build/outputs/aar/tunnel-release.aar app/wireguard-android/lib/wg-tunnel.aar; \
			touch app/wireguard-android/lib/marker; \
		fi \
	fi
