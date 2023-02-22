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

cd landing-github-pages
git checkout master
git pull
cd ..

cd landing

hash=$(git describe --abbrev=4 --always --tags --dirty)
echo "Syncing landing to live: $hash..."

yarn install
yarn build
cp -r dist/* ../landing-github-pages/
echo "$hash" > ../landing-github-pages/version.txt

cd ..

commit="publish landing: $hash"

cd landing-github-pages
git add .
git commit -am "$commit"
git tag "deploy-$hash"
git push
git push --tags

echo "Done"
