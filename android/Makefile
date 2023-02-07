all: sixcommon wireguard aab

sixcommon:
	@if test -d "six-common"; then \
		if test ! -d "app/six-common" || test "six-common" -nt "app/six-common/marker"; then \
			echo "Building six-common..."; \
			cd six-common && flutter build aar --no-profile && cd ../ ; \
			mkdir -p app/six-common; \
			cp -r six-common/build/host/outputs/repo app/six-common; \
			touch app/six-common/marker; \
		fi \
	fi

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

apk:
	@if test ! -f "app/build/outputs/apk/six/release/app-six-release.apk"; then \
		./gradlew assembleSixRelease; \
	fi

aab:
	@if test ! -f "app/build/outputs/bundle/sixRelease/app-six-release.aab"; then \
		./gradlew bundleSixRelease; \
	fi

clean:
	@rm -rf app/six-common; \
	rm -rf app/wireguard-android/lib; \
	./gradlew clean; \
	#cd six-common && flutter clean; \
	cd ..; \
	cd wireguard-android && ./gradlew clean; \

install:
	./gradlew installSixRelease

