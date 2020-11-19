#!/bin/sh

set -e

export PATH=$PATH:~/.cargo/bin:/usr/local/bin
export ANDROID_NDK_HOME=$ANDROID_NDK

echo "Using NDK location: $ANDROID_NDK_HOME"

JNI_LIBS=android4/app/src/tun-blocka/jniLibs

mkdir -p $JNI_LIBS/arm64-v8a
mkdir -p $JNI_LIBS/armeabi-v7a
mkdir -p $JNI_LIBS/x86
mkdir -p $JNI_LIBS/x86_64

cd boringtun

echo "Building for aarch64..."
cargo ndk --platform 21 --target aarch64-linux-android build --release --lib

echo "Building for arm7..."
cargo ndk --platform 21 --target armv7-linux-androideabi build --release --lib

echo "Building for x86..."
cargo ndk --platform 21 --target i686-linux-android build --release --lib

echo "Building for x86_64..."
cargo ndk --platform 21 --target x86_64-linux-android build --release --lib

cd ../
cp ./boringtun/target/aarch64-linux-android/release/libboringtun.so $JNI_LIBS/arm64-v8a/
cp ./boringtun/target/armv7-linux-androideabi/release/libboringtun.so $JNI_LIBS/armeabi-v7a/
cp ./boringtun/target/armv7-linux-androideabi/release/libboringtun.so $JNI_LIBS/x86/
cp ./boringtun/target/armv7-linux-androideabi/release/libboringtun.so $JNI_LIBS/x86_64/

echo "Done"
