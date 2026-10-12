#!/usr/bin/env bash
# Installs what an Android debug build needs in a Claude Code cloud session
# (Ubuntu, x86_64, root): the app's JDK, the fvm release pinned for CI with the
# Flutter version from common/.fvmrc, the Android SDK tools and the NDKs, which
# Gradle fails to download itself. Gradle fetches the rest. Safe to rerun.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
bin=/usr/local/bin
sdk=/opt/android-sdk

jdk=$(sed -n 's/^ *jvmToolchain *\([0-9]*\).*/\1/p' "$repo/android/app/build.gradle" | head -1)
if [ ! -d "/usr/lib/jvm/java-$jdk-openjdk-amd64" ]; then
  apt-get update -qq
  apt-get install -y -qq "openjdk-$jdk-jdk-headless" >/dev/null
fi

if ! command -v fvm >/dev/null; then
  action="$repo/.github/actions/setup-flutter/action.yml"
  fvm_version=$(sed -n 's/^ *FVM_VERSION: *"\(.*\)"/\1/p' "$action")
  fvm_sha=$(sed -n 's/^ *FVM_SHA256_LINUX_X64: *//p' "$action")
  curl -fsSL --retry 3 -o /tmp/fvm.tar.gz \
    "https://github.com/leoafarias/fvm/releases/download/$fvm_version/fvm-$fvm_version-linux-x64.tar.gz"
  echo "$fvm_sha  /tmp/fvm.tar.gz" | sha256sum -c -
  rm -rf /opt/fvm && tar -xzf /tmp/fvm.tar.gz -C /opt
  ln -sf /opt/fvm/fvm "$bin/fvm"
fi

if [ ! -x "$sdk/cmdline-tools/latest/bin/sdkmanager" ]; then
  zip=$(curl -fsSL --retry 3 https://dl.google.com/android/repository/repository2-3.xml |
    python3 -c 'import sys, xml.etree.ElementTree as ET
r = ET.parse(sys.stdin).getroot()
p = next(p for p in r.iter("remotePackage") if p.get("path") == "cmdline-tools;latest")
print(next(a.find("complete/url").text for a in p.iter("archive") if a.findtext("host-os") == "linux"))')
  curl -fsSL --retry 3 -o /tmp/cmdline-tools.zip "https://dl.google.com/android/repository/$zip"
  rm -rf /tmp/cmdline-tools && unzip -q /tmp/cmdline-tools.zip -d /tmp
  mkdir -p "$sdk/cmdline-tools" && rm -rf "$sdk/cmdline-tools/latest"
  mv /tmp/cmdline-tools "$sdk/cmdline-tools/latest"
fi
"$sdk/cmdline-tools/latest/bin/sdkmanager" platform-tools >/dev/null
ln -sf "$sdk/platform-tools/adb" "$bin/adb"
grep -qs '^sdk.dir=' "$repo/android/local.properties" || echo "sdk.dir=$sdk" >>"$repo/android/local.properties"

# Maven Central rate-limits the shared cloud egress IP; Google's mirror does not.
mkdir -p "$HOME/.gradle/init.d"
cat >"$HOME/.gradle/init.d/maven-mirror.gradle" <<'EOF'
def mirror = { handler ->
  handler.withType(MavenArtifactRepository).configureEach {
    if (url.toString().startsWith('https://repo.maven.apache.org/')) {
      url = 'https://maven-central.storage-download.googleapis.com/maven2/'
    }
  }
}
beforeSettings { settings ->
  mirror(settings.pluginManagement.repositories)
  mirror(settings.dependencyResolutionManagement.repositories)
  settings.gradle.allprojects { mirror(buildscript.repositories); mirror(repositories) }
}
EOF

cd "$repo/common"
# An explicit version keeps fvm from rewriting .fvmrc.
fvm install "$(jq -r .flutter .fvmrc)"
fvm flutter config --android-sdk "$sdk" >/dev/null
fvm flutter precache --android

flutter_root=$(fvm flutter --version --machine | jq -r .flutterRoot)
ln -sf "$flutter_root/bin/flutter" "$bin/flutter"
ln -sf "$flutter_root/bin/dart" "$bin/dart"
mapfile -t ndks < <(sed -n 's/.*ndkVersion[^=]*= *"\([^"]*\)".*/\1/p' "$repo/android/build.gradle" \
  "$flutter_root/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt" | sort -u)
"$sdk/cmdline-tools/latest/bin/sdkmanager" "${ndks[@]/#/ndk;}" >/dev/null
