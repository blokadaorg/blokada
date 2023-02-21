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

./sync-translations.sh

# Drops leading zeros
major=${2#0}
minor=${3#0}

tag="$1.$major.$minor"
code="$1$2$3"
commit="release: $tag"

echo "Marking release: $tag..."

sed -Ei '' "s/CURRENT_PROJECT_VERSION = ((23|24|25).*)\;/CURRENT_PROJECT_VERSION = $code\;/; s/MARKETING_VERSION = ((23|24|25).*)\;/MARKETING_VERSION = $tag\;/" IOS.xcodeproj/project.pbxproj
git add IOS.xcodeproj/project.pbxproj
git commit -m "$commit"
git tag $tag

echo "Done. Run this to push:"
echo "git push --atomic origin main $tag"
