#!/bin/bash

set -euo pipefail

mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
echo "$PROVISIONING_PROFILE_DATA_APP" | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/profile-app.mobileprovision
echo "$PROVISIONING_PROFILE_DATA_NETWORKEXTENSION" | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/profile-networkextension.mobileprovision

