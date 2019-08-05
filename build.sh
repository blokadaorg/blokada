#!/bin/sh
JNI_LIBS=../app/src/vpn/jniLibs

export PATH=$PATH:$NDK_STANDALONE/arm64/bin
export PATH=$PATH:$NDK_STANDALONE/x86/bin

rm -rf $JNI_LIBS
mkdir $JNI_LIBS
mkdir $JNI_LIBS/arm64-v8a
mkdir $JNI_LIBS/armeabi-v7a
mkdir $JNI_LIBS/x86

echo "Building for armv7..."
cargo build --lib --release --target armv7-linux-androideabi
cp target/armv7-linux-androideabi/release/libboringtun.so $JNI_LIBS/armeabi-v7a/libboringtun.so

echo "Building for aarch64..."
export CC=aarch64-linux-android-gcc
export CXX=aarch64-linux-android-g++
cargo build --lib --release --target aarch64-linux-android
cp target/aarch64-linux-android/release/libboringtun.so $JNI_LIBS/arm64-v8a/libboringtun.so

echo "Building for i686..."
export CC=i686-linux-android-gcc
export CXX=i686-linux-android-g++
cargo build --lib --release --target i686-linux-android
cp target/i686-linux-android/release/libboringtun.so $JNI_LIBS/x86/libboringtun.so
