all: sixcommon ipa

sixcommon:
	@echo "Building six-common..."; \
	cd six-common && ./build.for.ios.sh && cd ../ ; \

ipa:
	@fastlane run build_app scheme:"IOS"; \

clean:
	@fastlane run clean_build_artifacts; \
	cd six-common && flutter clean; \
