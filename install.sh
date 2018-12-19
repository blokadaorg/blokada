#!/bin/sh
JNI_LIBS=../app/src/main/jniLibs

cd boringtun
#cargo build --lib --release --target aarch64-linux-android
cargo build --lib --release --target armv7-linux-androideabi
#cargo build --lib --release --target i686-linux-android

rm -rf $JNI_LIBS
mkdir $JNI_LIBS
mkdir $JNI_LIBS/arm64-v8a
mkdir $JNI_LIBS/armeabi-v7a
mkdir $JNI_LIBS/x86

#cp target/aarch64-linux-android/release/libboringtun.so $JNI_LIBS/arm64-v8a/libboringtun.so
cp target/armv7-linux-androideabi/release/libboringtun.so $JNI_LIBS/armeabi-v7a/libboringtun.so
#cp target/i686-linux-android/release/libboringtun.so $JNI_LIBS/x86/libboringtun.so

cd ../
./gradlew iAHD
