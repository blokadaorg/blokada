#!/bin/sh

set -e

echo "Building common..."

version=$(git describe --abbrev=4 --always --tags --dirty)

built=false
if [ -e build/.version ]; then
  built_version=$(<build/.version)
  if [[ "$version" = *-dirty ]]; then
    built=false # always reubild dirty head
  elif [[ "$version" == "$built_version" ]]; then
    built=true
  else
    built=false
  fi
fi

if [[ "$built" = true ]]; then
	echo "Skipping, already built"
else
	flutter build ios-framework --output=build/ios-framework --no-debug --no-profile
	echo $version > build/.version
fi

echo "Done"
