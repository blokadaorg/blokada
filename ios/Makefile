all: sixcommon build
.PHONY: family

sixcommon:
	@echo "Building six-common..."; \
	cd six-common && ./build.for.ios.sh && cd ../ ; \

forsimulator:
	@echo "Building six-common debug for simulator..."; \
	cd six-common && flutter build ios-framework --output=build/ios-framework --no-profile --no-release


build:
	@xcodebuild build -project IOS.xcodeproj -scheme "Prod" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO; \

test:
	@xcodebuild build test -project IOS.xcodeproj -scheme "Prod" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO; \

clean:
	@fastlane run clean_build_artifacts; \
	cd six-common && flutter clean; \

clean-sixcommon:
	@cd six-common && flutter clean && cd ../ ; \

devsc:
	@echo "Fetch latest six-common"; \
	( \
		cd six-common && \
		git pull --rebase origin main && \
		flutter clean && \
		./build.for.ios.sh --onlydebug \
	)

devsc2:
	@echo "Fetch latest six-common (force)"; \
	cd six-common && git reset --hard && git pull --rebase && cd ../ ; \
	cd six-common && flutter clean && cd ../ ; \
	cd six-common && ./build.for.ios.sh --onlydebug && cd ../ ; \

family:
	@xcodebuild build -project IOS.xcodeproj -scheme "FamilyProd" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO; \

v6:
	@xcodebuild build -project IOS.xcodeproj -scheme "Prod" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO; \
