PACKAGE_PREFIX?=org.blokada
ACTIVITY_PREFIX?=org.blokada.ui.app.android
FLAVOR?=Dev
VARIANT?=Debug
PACKAGE?=.dev
GRADLE?=./gradlew

FLAVOR_LC=`echo $(FLAVOR) | tr A-Z a-z`
VARIANT_LC=`echo $(VARIANT) | tr A-Z a-z`

# Default target
all: ass in start

# Build ($(GRADLE)) aliases

ass:
	$(GRADLE) assemble$(FLAVOR)$(VARIANT)

test:
	$(GRADLE) lint$(FLAVOR)$(VARIANT) test$(FLAVOR)$(VARIANT)

atest:
	$(GRADLE) androidTest$(FLAVOR)$(VARIANT)

clean:
	$(GRADLE) clean

in:
	adb install -r app/build/outputs/apk/app-$(FLAVOR_LC)-$(VARIANT_LC).apk

un:
	adb uninstall $(PACKAGE_PREFIX)$(PACKAGE)

rein: un in

deps:
	$(GRADLE) app:dependencies

# Git convenience

version-name:
	git describe --tags --dirty

# ADB convenience

start:
	adb shell am start -n $(PACKAGE_PREFIX)$(PACKAGE)/$(ACTIVITY_PREFIX).MainActivity

stop:
	adb shell am force-stop $(PACKAGE_PREFIX)$(PACKAGE)

restart: stop start

cleandata:
	adb shell pm clear $(PACKAGE_PREFIX)$(PACKAGE)

.PHONY: ass test atest clean in un rein deps version-name start stop restart cleardata
