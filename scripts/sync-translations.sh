#!/bin/sh

echo "Syncing strings..."

cd deps/translate/scripts
git checkout master
git pull
hash=$(git describe --abbrev=4 --always --tags --dirty)
commit="sync: update translate strings to: $hash"

echo $commit

./translate.py -a common -t ../../../common
./translate.py -a ios -t ../../../ios
./translate.py -a android5 -t ../../../android

cd ../../../

#echo "Running gen-l10n for common..."
#flutter gen-l10n

git commit -am "$commit"

echo "Done"
