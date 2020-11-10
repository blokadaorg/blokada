# Building Blokada

#### This is a general set-up guide for people interested in contributing to Blokada development.

**IMPORTANT NOTICE**: This guide intended for Linux users

These instructions will give you some insights on how to

* setup RUST for Android development
* use NDK toolchains
* generate signing key with `keytool` (JDK)
* launch Blokada on an Android device

## Prerequisites

* Clone the project repository `git clone https://github.com/blokadaorg/blokada.git` in your desired location.

* Make sure that you have [JDK](https://www.oracle.com/java/technologies/javase-downloads.html) installed on your machine

* Make sure that you also have `android-tools` installed which can be found on most distributions.

### The Android NDK toolchains

[NDK DOWNLOAD](https://developer.android.com/ndk/downloads/)

It's advised that the files from the downloaded NDK are stored in either `$HOME/.NDK` or in `$HOME/Android` which could be the same as `$ANDROID_HOME` if you have it set.

## RUST and Boringtun preparations

Rust is fairly easy to install with the tool **rustup**.rs. We need it to compile [Boringtun](https://github.com/blokadaorg/blokada/tree/master/boringtun).

1. Simply copy and paste the following command in a terminal and follow the instructions: `curl https://sh.rustup.rs -sSf | sh` Depending on the shell you are using **rust** might **NOT** be in your $PATH. Run `rustc --version` to verify if this is the case.

2. Next up we need to add the target Android architectures as they are not provided by default: `rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android`

3. Now we need to tell RUST about the NDK toolchains. We'll make it a project-specific `cargo` configuration. In our case `blokada_root_dir/boringtun/.cargo/config`. This part could be problematic if we haven't set the proper paths to the toolchains. 
Here is an example using `$HOME/Android/android-ndk-r21` as our path to the files we need:
```
[target.armv7-linux-androideabi]
ar = "/home/user/Android/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/arm-linux-androideabi-ar"
linker = "/home/user/Android/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang"

[target.aarch64-linux-android]
ar = "/home/user/Android/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android-ar"
linker = "/home/user/Android/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang"

[target.i686-linux-android]
ar = "/home/user/Android/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/i686-linux-android-ar"
linker = "/home/user/Android/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/i686-linux-android21-clang"

[target.x86_64-linux-android]
ar = "/home/user/Android/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android-ar"
linker = "/home/user/Android/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android21-clang"
```

4. We need to edit the helper script `build.sh` located in the `blokada/boringtun` directory. Add the following line **BEFORE** the line that starts with `export...`

    `export NDK_STANDALONE=$HOME/Android/android-ndk-r21`
        This will ensure that all the files from the toolchains we need are in the right place.

5. Run the newly-edited `build.sh` script and wait to see if all the builds succeed.

## Generating and using keys

In order to succesfully build Blokada on our device we need to generate Android signing keys and then add them to `~/.gradle/gradle.properties`.

If you haven't generated any keys before consider creating a directory for them `mkdir ~/keystores`

1. Generate a key and a keystore like so `keytool -genkey -v -keystore ~/keystores/EXAMPLE.keystore -alias blokada -keypass PASSWORD`. Keep the alias as is and change **PASSWORD** and **EXAMPLE** to your liking. The generation tool will then prompt you for a password for your keystore (**REMEMBER IT**) which we will use in the next step.

2. Now we need to edit the file `$HOME/.gradle/gradle.properties`. Let's assume that we use the **exact** command from the previous step. **IMPORTANT**: `BLOKADA_STORE_PASSWORD=` should be set to the **same password** as the one prompted by `keytool`!
```
BLOKADA_KEY_PASSWORD=PASSWORD
BLOKADA_KEY_PATH=/home/user/EXAMPLE.keystore
BLOKADA_STORE_PASSWORD=
```

3. To make sure everything is fine with the keys we can run `./gradlew signingReport` in the Blokada project root directory.

## The device we will be testing on

After making sure that the device has Developper Settings and USB Debugging enable, connect it to your laptop/desktop. Open a terminal once more and check if your device is connected properly with `adb devices` command.

If your device is recognized navigate to the blokada project directory and run `./gradlew iFD`. The iFD stands for "installFullDebug". Hopefully everything will run smoothly and you will have your very own custom Beta Blokada build :).

#### Helpful gradle commands:

* check if signing is set properly `./gradlew signingReport`
* see available tasks for the current project `./gradlew tasks`
* gradle options `./gradlew --help`
* uninstall a test build from the phone `./gradlew uFD` or `./gradlew uA` (uFD - uninstallFullDebug; uA - uninstallAll)
