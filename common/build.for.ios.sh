#!/bin/sh

set -e

flutter build ios-framework --output=build/ios-framework --no-debug --no-profile

echo "Done"
