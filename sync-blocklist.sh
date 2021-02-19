#!/bin/sh

echo "Syncing default blocklist"

cp ../landing-github-pages/mirror/v5/oisd/light/hosts.txt ios/Engine/hosts.txt
cp ios/Engine/hosts.txt android5/app/src/main/assets/default_blocklist
cd android5/app/src/main/assets/
rm default_blocklist.zip
zip -e default_blocklist.zip default_blocklist
rm default_blocklist
cd ../../../../
echo "Done"
git add .
git ci -am "sync: update default blocklist"
