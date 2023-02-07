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

echo "Building common..."

cd six-common
hash=$(git describe --abbrev=4 --always --tags --dirty)
commit="sync: update six-common to: $hash"

echo $commit

flutter build aar --no-profile
mkdir -p libs/six-common/
cp -r build/host/outputs/repo/ libs/six-common

cd ../

git commit -am "$commit"

echo "Done"
