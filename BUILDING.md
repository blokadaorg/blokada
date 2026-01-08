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
- cocoapods
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
$ gem install cocoapods --user-install
$ gem install bundler
$ pod install --repo-update
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

If there are any problems with iOS dependencies, you may need to do (in ios dir):
```
$ rm Podfile.lock
$ pod install --repo-update
```

Now see fastlane/README.md for more details on how to build the apps.

## Notes for the Flutter module
- The Flutter module lives at `blokada/common`.
- Pigeon Dart outputs are generated under `lib/src/platform/**/channel.pg.dart`; the old `lib/platform/**` path is removed.
- Use the Make targets above (`make analyze`, `make test`, `make build-*`) instead of calling Flutter commands directly.
