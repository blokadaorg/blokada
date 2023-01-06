#!/bin/sh

echo "Syncing common..."

cd six-common
git checkout main
git pull
hash=$(git describe --abbrev=4 --always --tags --dirty)
commit="sync: update six-common to: $hash"

echo $commit

cd ../

git commit -am "$commit"

echo "Done"
