#!/bin/sh

#
# This file is part of Blokada.
#
# Blokada is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Blokada is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
#
# Copyright © 2020 Blocka AB. All rights reserved.
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
