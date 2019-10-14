#!/bin/sh
JNI_LIBS=../app/src/tun-blocka/jniLibs

export PATH=$PATH:$NDK_STANDALONE/arm/bin
export PATH=$PATH:$NDK_STANDALONE/arm64/bin
export PATH=$PATH:$NDK_STANDALONE/x86/bin
export PATH=$PATH:$NDK_STANDALONE/x86_64/bin

rm -rf $JNI_LIBS
mkdir $JNI_LIBS
mkdir $JNI_LIBS/armeabi-v7a
mkdir $JNI_LIBS/arm64-v8a
mkdir $JNI_LIBS/x86
mkdir $JNI_LIBS/x86_64

echo "Building for armv7..."
cargo build --lib --release --target armv7-linux-androideabi
cp target/armv7-linux-androideabi/release/libboringtun.so $JNI_LIBS/armeabi-v7a/libboringtun.so

echo "Building for aarch64..."
cargo build --lib --release --target aarch64-linux-android
cp target/aarch64-linux-android/release/libboringtun.so $JNI_LIBS/arm64-v8a/libboringtun.so

echo "Building for i686..."
cargo build --lib --release --target i686-linux-android
cp target/i686-linux-android/release/libboringtun.so $JNI_LIBS/x86/libboringtun.so

echo "Building for v86_64..."
cargo build --lib --release --target x86_64-linux-android
cp target/x86_64-linux-android/release/libboringtun.so $JNI_LIBS/x86_64/libboringtun.so
