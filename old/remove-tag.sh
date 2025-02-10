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
  echo "Error: You must provide the version tag. ./remove-tag.sh TAG" >&2
  exit 1
fi

echo "Removing tag: $1..."

git tag -d $1
git push origin :$1

echo "Done"
