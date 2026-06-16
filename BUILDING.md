# Installing

## Docker image

Blokada Android apps can be built with docker using image blokadaorg/docker-apps-build-box.
As of now, iOS apps need to be built manually.

## Requirements (for manual building)
For minimum versions needed see the Dockerfile.

- python3
- flutter
- android SDK
- java17
- fastlane

- Xcode
- ruby
- bundler
- swiftlint
- go

Rough installation instructions for macos:

```
$ brew install python3
$ (android SDK can be installed with Android Studio)
$ brew install --cask temurin@17
$ brew install fastlane
$ export ANDROID_HOME=<sdk-path>

$ (install Xcode from AppStore)
$ sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
$ sudo xcodebuild -runFirstLaunch
$ brew install ruby
$ export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
$ export PATH="$HOME/.gem/ruby/3.4.0/bin:$PATH"
$ gem install bundler   # for fastlane
$ brew install swiftlint go@1.22
$ export PATH="/opt/homebrew/opt/go@1.22/bin:$PATH"

$ brew tap leoafarias/fvm
$ brew install fvm
$ cd common/
$ fvm install && fvm use
$ fvm flutter config --jdk-dir <java-path>
$ fvm flutter doctor
$ make analyze   # static analysis for the Flutter module
$ make test      # flutter tests for the Flutter module

$ make regen-ios
```

Also don't forget the following:
```
$ git submodule update --init --recursive

// for iOS signing (from ios dir):
fastlane match development
...
```

iOS native dependencies use Swift Package Manager, resolved by Xcode (Firebase,
Factory, CodeScanner). The Flutter module is consumed as prebuilt xcframeworks:
`make -C common build-ios` produces them under `common/build/ios-framework/`,
which the host project links and embeds. If iOS deps look stale, rebuild with:
```
$ make -C common build-ios
```

To debug the embedded Flutter engine (`flutter attach`, breakpoints) set the
LLDB init file once, per https://docs.flutter.dev/to/ios-add-to-app-embed-setup
("Use frameworks > Set LLDB Init File").

Now see fastlane/README.md for more details on how to build the apps.

## Notes for the Flutter module
- The Flutter module lives at `blokada/common`.
- Pigeon Dart outputs are generated under `lib/src/platform/**/channel.pg.dart`; the old `lib/platform/**` path is removed.
- Use the Make targets above (`make analyze`, `make test`, `make build-*`) instead of calling Flutter commands directly.
