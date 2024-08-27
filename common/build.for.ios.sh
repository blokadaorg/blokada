#!/bin/sh

set -e

echo "Building common..."

version=$(git describe --abbrev=4 --always --tags --dirty)

built=false
if [ -e build/.version ]; then
  built_version=$(<build/.version)
  if [[ "$version" = *-dirty ]]; then
    built=false # always rebuild dirty head
  elif [[ "$version" == "$built_version" ]]; then
    built=true
  else
    built=false
  fi
fi

if [[ "$built" = true ]]; then
	echo "Skipping, already built"
else
	flutter pub get
	./sync-generated-files.sh
	if [ -z "$1" ]; then
		fvm flutter build ios-framework --output=build/ios-framework --no-profile
	else
		fvm flutter build ios-framework --output=build/ios-framework --no-release --no-profile
	fi
	echo $version > build/.version
fi

echo "Done"
