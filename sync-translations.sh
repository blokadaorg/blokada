#!/bin/sh

echo "Syncing strings (will push)"

cd translate/scripts
git checkout master
git pull
hash=$(git rev-parse --short HEAD)
commit="translate: sync strings to: $hash"

echo $commit

./translate.py -a android4

cd ../../

git commit -am "$commit"
git push

echo "Done"
