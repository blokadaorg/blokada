#!/bin/sh

#
# This file is part of Blokada.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright © 2021 Blocka AB. All rights reserved.
#
# @author Karol Gusak (karol@blocka.net)
#

# I couldnt make that gradle rust android plugin work

export ANDROID_NDK_HOME=$ANDROID_HOME/ndk-bundle/
cd ../blocka_engine

echo "Building for arm"
cargo ndk --target armv7-linux-androideabi --android-platform 22 -- build --release

echo "Building for arm64"
cargo ndk --target aarch64-linux-android --android-platform 22 -- build --release

echo "Building for x86"
cargo ndk --target i686-linux-android --android-platform 22 -- build --release

echo "Building for x86_64"
cargo ndk --target x86_64-linux-android --android-platform 22 -- build --release

cd ../android

echo "Copying files"
cp ../blocka_engine/target/armv7-linux-androideabi/release/libblocka_dns.so ./app/src/engine/jniLibs/armeabi-v7a/
cp ../blocka_engine/target/aarch64-linux-android/release/libblocka_dns.so ./app/src/engine/jniLibs/arm64-v8a/
cp ../blocka_engine/target/i686-linux-android/release/libblocka_dns.so ./app/src/engine/jniLibs/x86/
cp ../blocka_engine/target/x86_64-linux-android/release/libblocka_dns.so ./app/src/engine/jniLibs/x86_64/

echo "Done."
