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

set -e

echo "Publishing Blokada 5 for Android: $1..."

cd five-android
git co main 
git pull
git co $1
git submodule update

cd ../

commit="publish Blokada 5 for Android: $1"
tag="android.v5.$1"

git add five-android
git commit -m "$commit"
git tag $tag

git push
git push --tags

echo "Done"
