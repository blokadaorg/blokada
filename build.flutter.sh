#!/bin/sh

set -e

cd common/

flutter build ios-framework --output=build/ios-framework

echo "Done"
