#!/bin/bash

set -euo pipefail

SCHEME="$(xcodebuild -list -json -project IOS.xcodeproj | jq -r '.project.schemes[0]')"
PRODUCT_NAME="$(xcodebuild -scheme "$SCHEME" -showBuildSettings -project IOS.xcodeproj | grep " PRODUCT_NAME " | sed "s/[ ]*PRODUCT_NAME = //")"
echo "name=PRODUCT_NAME::$PRODUCT_NAME" >> $GITHUB_ENV

