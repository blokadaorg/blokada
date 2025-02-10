#!/bin/sh

echo "Syncing strings..."

cd translate/scripts
git checkout master
git pull
hash=$(git describe --abbrev=4 --always --tags --dirty)
commit="sync: update translate strings to: $hash"

echo $commit

./translate.py -a ios

cd ../../

echo "Running swiftgen for ios..."
swiftgen


git commit -am "$commit"

echo "Done"
