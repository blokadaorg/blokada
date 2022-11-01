#!/bin/sh

set -e

export PATH=$PATH:~/.cargo/bin:/usr/local/bin
export ANDROID_NDK_HOME=$ANDROID_NDK

# Last NDK known to build fine: 22.1.7171670
echo "Using NDK location: $ANDROID_NDK_HOME"

JNI_LIBS=android5/app/src/libre/jniLibs

mkdir -p $JNI_LIBS/arm64-v8a
mkdir -p $JNI_LIBS/armeabi-v7a

cd blocka_engine/blocka_dns

echo "Building for aarch64..."
cargo ndk --platform 21 --target aarch64-linux-android build --release

echo "Building for arm7..."
cargo ndk --platform 21 --target armv7-linux-androideabi build --release

cd ../../
cp ./blocka_engine/target/aarch64-linux-android/release/libblocka_dns.so $JNI_LIBS/arm64-v8a/
cp ./blocka_engine/target/armv7-linux-androideabi/release/libblocka_dns.so $JNI_LIBS/armeabi-v7a/

echo "Done"
