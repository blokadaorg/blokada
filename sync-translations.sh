#!/bin/sh

echo "Syncing strings..."

cd translate/scripts
git checkout master
git pull
hash=$(git rev-parse --short HEAD)
commit="translate: sync strings to: $hash"

echo $commit

./translate.py -a android5
./translate.py -a ios
./translate.py -a common

cd ../../

echo "Running swiftgen for ios..."
cd ios/
swiftgen
cd ../


git commit -am "$commit"

echo "Done"
