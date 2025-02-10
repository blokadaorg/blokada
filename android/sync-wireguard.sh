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

echo "Syncing wireguard-android..."

cd wireguard-android
hash=$(git describe --abbrev=4 --always --tags --dirty)
commit="sync: update wireguard-android to: $hash"
echo $commit
cd ../

git commit -am "$commit"

echo "Done (run make now)."
