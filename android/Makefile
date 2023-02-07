all: sixcommon wireguard aab

sixcommon:
	@if test -d "six-common"; then \
		if test ! -d "libs/six-common" || test "six-common" -nt "libs/six-common/marker"; then \
			cd six-common; \
			flutter build aar --no-profile; \
			mkdir -p ../libs/six-common/; \
			cp -r build/host/outputs/repo/ ../libs/six-common; \
			touch ../libs/six-common/marker; \
		fi \
	fi

wireguard:
	@if test -d "wireguard-android"; then \
		if test ! -d "libs/wireguard-android" || test "wireguard-android" -nt "libs/wireguard-android/marker"; then \
			cd wireguard-android; \
			./gradlew tunnel:build; \
			mkdir -p ../libs/wireguard-android; \
			cp tunnel/build/outputs/aar/tunnel-release.aar ../libs/wireguard-android/wg-tunnel.aar; \
			touch ../libs/wireguard-android/marker; \
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
	@rm -rf libs/*; \
	./gradlew clean; \
	#cd six-common && flutter clean; \
	cd ..; \
	cd wireguard-android && ./gradlew clean; \

install:
	./gradlew installSixRelease

