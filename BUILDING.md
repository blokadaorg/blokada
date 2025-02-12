# Installing


## use docker image (android only)


## manual (android)

python3
brew install --cask flutter

android sdk (installed android studio)

#java
brew install --cask temurin@21

flutter doctor

flutter config --jdk-dir

fastlane

env vars


## manual (ios)

xcode

sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

(cocoapods - flutter)
# Newer ruby
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="$HOME/.gem/ruby/3.4.0/bin:$PATH"
brew install ruby
gem install cocoapods --user-install

(go - wireguard-apple)
brew install swiftlint go@1.22
export PATH="/opt/homebrew/opt/go@1.22/bin:$PATH"

fastlane:
gem install bundler
