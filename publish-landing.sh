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

if [ "$#" -ne 1 ]; then
  echo "Error: You must provide the version tag. ./publish-landing.sh TAG" >&2
  exit 1
fi

echo "Publishing landing: $1..."

cd landing
git co main
git pull
git co $1
git submodule update

cd ../

./sync-landing.sh

commit="publish landing: $1"
tag="landing.$1"

git add landing
git add landing-github-pages
git commit -m "$commit"
git tag $tag

git push
git push --tags

echo "Done"
