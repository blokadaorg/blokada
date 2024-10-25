.PHONY: build get gen web android ios test clean

build: get gen web

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
