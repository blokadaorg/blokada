.PHONY: all get gen web android ios test clean

all: get gen ios android

web:
	flutter build web

android:
	flutter build aar --no-profile --no-debug

ios:
	flutter build ios-framework --no-profile --no-debug

get:
	flutter pub get

gen:
	./sync-generated-files.sh

test:
	flutter test

clean:
	flutter clean
