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

# CI (translations-sync.yml) sets SKIP_COMMIT=1 so it can stage and commit the
# diff itself under the blokada-ci App identity. Run by hand without it for the
# normal local flow, where this commit is what you want.
if [ -z "${SKIP_COMMIT:-}" ]; then
  git commit -am "$commit"
else
  echo "SKIP_COMMIT set; leaving changes uncommitted for CI to stage."
fi

echo "Done"
