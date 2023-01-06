#!/bin/sh

echo "Syncing strings..."

cd translate/scripts
git checkout master
git pull
hash=$(git rev-parse --short HEAD)
commit="translate: sync strings to: $hash"

echo $commit

./translate.py -a ios

cd ../../

echo "Running swiftgen for ios..."
swiftgen


git commit -am "$commit"

echo "Done"
