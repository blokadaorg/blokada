#!/bin/sh

echo "Syncing generated files..."

echo "Running pigeon..."
rm -rf libgen/ios
rm -rf libgen/android
mkdir -p libgen/ios
mkdir -p libgen/android
for file in libgen/schema/*.dart
do
    name=$(basename "$file" | cut -f 1 -d '.')
    dartPath=$(echo "$name" | sed 's/\([A-Z]\)/\/\1/g')
    dartPath=$(echo $dartPath | tr '[:upper:]' '[:lower:]')
    echo $dartPath
    flutter pub run pigeon --input $file --dart_out lib$dartPath/channel.pg.dart --swift_out libgen/ios/$name.swift --kotlin_out libgen/android/$name.kt --kotlin_package "channel"
done

echo "Running flutter build_runner..."
flutter pub run build_runner build --delete-conflicting-outputs

echo "Done"
