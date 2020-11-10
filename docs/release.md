Release procedure

update repo links (version code dir, flavors)
upload strings_*.xml to translations
upload strings_*.properties from the repo to translations
upload *.html from the repo to translations (homepage too)
download translated strings_*.xml in a zip and put it into values-xx
download the rest of translation files and put them onto repo

vim app/version.gradle
git tag $VER
git push origin remote
git push --tags
make test
make clean
./makef all release ass
mkdir $BLOKADA_APK/$VER
cp app/build/outputs/apk/app-* $BLOKADA_APK/$VER/
cp -r app/build/outputs/mapping* $BLOKADA_APK/$VER/
ls -la $BLOKADA_APK/$VER/ && tree $BLOKADA_APK/$VER/
vim $BLOKADA_APK/$VER/changelog
cp $BLOKADA_APK/$VER/changelog $BLOKADA_GITHUB/...
add html to that changelog
run new release builds on various devices and test
upload apk to hosts: github, dropbox
update beta channels: apk link, xda-forum/labs, maybe updater trial
if all good, update stable channels: blokada.org, udpater, amazon, aptoide
update mapping in analytics
social media
advertise the new release to the buglist users
