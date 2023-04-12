.PHONY: all get gen build test clean

all: get gen build

build:
	flutter build web

get:
	flutter pub get

gen:
	./sync-generated-files.sh

test:
	flutter test

clean:
	flutter clean
