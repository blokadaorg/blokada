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

if [ "$#" -ne 3 ]; then
  echo "Error: You must provide the version number. ./release.sh XX YY ZZ" >&2
  exit 1
fi

# Drops leading zeros
major=${2#0}
minor=${3#0}

tag="$1.$major.$minor"
commit="release: $tag"

echo "Marking release: $tag..."

sed -i '' "s/versionCode .*/versionCode 666$1$2$3/; s/versionName .*/versionName \"$tag\"/" app/build.gradle
git add app/build.gradle
git commit -m "$commit"
git tag $tag

git push
git push --tags

echo "Done"
