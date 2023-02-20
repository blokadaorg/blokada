all: sixcommon ipa

sixcommon:
	@echo "Building six-common..."; \
	cd six-common && ./build.for.ios.sh && cd ../ ; \

build:
	@xcodebuild build -project IOS.xcodeproj -scheme "IOS" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO; \

test:
	@xcodebuild build test -project IOS.xcodeproj -scheme "IOS" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO; \

clean:
	@fastlane run clean_build_artifacts; \
	cd six-common && flutter clean; \
