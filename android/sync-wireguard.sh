#!/bin/sh

#
# This file is part of Blokada.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright © 2023 Blocka AB. All rights reserved.
#
# @author Karol Gusak (karol@blocka.net)
#

echo "Building wireguard-android..."

cd wireguard-android
hash=$(git describe --abbrev=4 --always --tags --dirty)
commit="sync: update wireguard-android to: $hash"

echo $commit

#./gradlew tunnel:clean
./gradlew tunnel:build
mkdir -p ../app/wireguard-android/lib
cp tunnel/build/outputs/aar/tunnel-release.aar ../app/wireguard-android/lib/wg-tunnel.aar

cd ../

git commit -am "$commit"

echo "Done."
