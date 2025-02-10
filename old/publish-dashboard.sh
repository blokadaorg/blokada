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
  echo "Error: You must provide the version tag. ./publish-dashboard.sh TAG" >&2
  exit 1
fi

echo "Publishing dashboard: $1..."

cd dashboard
git co main
git pull
git co $1
make deploy

cd ../

commit="publish dashboard: $1"
tag="dashboard.$1"

git add dashboard
git commit -m "$commit"
git tag $tag

git push
git push --tags

echo "Done"
