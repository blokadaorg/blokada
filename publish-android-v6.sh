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

echo "Publishing Blokada 6 for Android: $1..."

cd six-android
git co main 
git pull
git co $1

cd ../

commit="publish Blokada 6 for Android: $1"
tag="android.v6.$1"

git add six-android
git commit -m "$commit"
git tag $tag

git push
git push --tags

echo "Done"
