# Define common variables 
# none for now
 
# Default target 
.DEFAULT_GOAL := build
 
.PHONY: clean build
 
clean: 
	$(MAKE) -C common/ clean
	$(MAKE) -C android/ clean


# Build everything from scratch for release and publish
build:
	$(MAKE) -C common/ build
	$(MAKE) -C android/ build


# Various build targets (release)
build-android-family:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ aab-family

build-android-v6:
	$(MAKE) -C common/ build-android
	$(MAKE) -C android/ aab-v6


# Debug build targets for development
d-build-android-family:
	$(MAKE) -C common/ get-deps
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ d-lib-android
	$(MAKE) -C android/ aab-family


# Quick targeted recompilation targets for development
dq-deps:
	$(MAKE) clean
	$(MAKE) -C common/ get-deps

dq-android:
	$(MAKE) -C common/ gen-pigeon-android
	$(MAKE) -C common/ gen-build-runner
	$(MAKE) -C common/ d-lib-android

dq-ifam:
	$(MAKE) -C android/ d-install-family

dq-isix:
	$(MAKE) -C android/ d-install-six



# OLD to be removed

sixcommon:
	@if test -d "six-common"; then \
		if test ! -d "app/six-common" || test "six-common" -nt "app/six-common/marker"; then \
			echo "Building six-common..."; \
			cd six-common && make get gen && cd ../ ; \
			cd six-common && flutter build aar --no-profile && cd ../ ; \
			mkdir -p app/six-common; \
			cp -r six-common/build/host/outputs/repo app/six-common; \
			touch app/six-common/marker; \
		fi \
	fi

