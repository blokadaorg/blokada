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
$ brew install --cask flutter
$ (android SDK can be installed with Android Studio)
$ brew install --cask temurin@17
$ brew install fastlane
$ flutter config --jdk-dir <java-path>
$ export ANDROID_HOME=<sdk-path>

$ (install Xcode from AppStore)
$ sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
$ sudo xcodebuild -runFirstLaunch
$ brew install ruby
$ export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
$ export PATH="$HOME/.gem/ruby/3.4.0/bin:$PATH"
$ gem install cocoapods --user-install
$ gem install bundler
$ brew install swiftlint go@1.22
$ export PATH="/opt/homebrew/opt/go@1.22/bin:$PATH"

$ flutter doctor
```

Also don't forget the following:
```
git submodule update --init --recursive

// for iOS signing (from ios dir):
fastlane match development
...
```
