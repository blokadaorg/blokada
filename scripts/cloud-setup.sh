#!/usr/bin/env bash
# Installs what an Android debug build needs in a Claude Code cloud session
# (Ubuntu, x86_64, root): the app's JDK, the fvm release pinned for CI with the
# Flutter version from common/.fvmrc, the Android SDK tools, the NDKs and the
# compile platform, the build-tools and plugin platforms, and kubectl for
# tools/emu. Gradle fetches the rest. Safe to rerun.
#
# A cloud environment caches its setup only when it finishes in about five
# minutes, so the work runs as independent chains in parallel: Flutter (fvm,
# SDK, precache), Android (JDK and SDK tools, then NDKs and platform), kubectl.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
bin=/usr/local/bin
sdk=/opt/android-sdk
sdkmanager="$sdk/cmdline-tools/latest/bin/sdkmanager"
flutter_version=$(jq -r .flutter "$repo/common/.fvmrc")
# What the first debug build otherwise downloads mid-build: AGP's default
# build-tools and the platforms the Flutter plugins compile against. Parallel
# builds downloading them into the shared SDK at once leave them half-unpacked.
build_packages=("build-tools;36.0.0" "platforms;android-34" "platforms;android-35" "platforms;android-36")
# Where a Flutter checkout pins the NDK its Gradle plugin builds with.
flutter_ext=packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt

ndk_versions() { # ndk_versions [file]...: ndkVersion values the given build files (or stdin) pin
  sed -n 's/.*ndkVersion[^=]*= *"\([^"]*\)".*/\1/p' "$@"
}

install_jdk() {
  local jdk
  jdk=$(sed -n 's/^ *jvmToolchain *\([0-9]*\).*/\1/p' "$repo/android/app/build.gradle" | head -1)
  if [ ! -d "/usr/lib/jvm/java-$jdk-openjdk-amd64" ]; then
    apt-get update -qq
    apt-get install -y -qq "openjdk-$jdk-jdk-headless" >/dev/null
  fi
}

# kubectl for tools/emu, which reaches its device pod through the Kubernetes API.
install_kubectl() {
  command -v kubectl >/dev/null && return
  local kv
  kv=$(curl -fsSL --retry 3 https://dl.k8s.io/release/stable.txt)
  curl -fsSL --retry 3 -o /tmp/kubectl "https://dl.k8s.io/release/$kv/bin/linux/amd64/kubectl"
  echo "$(curl -fsSL --retry 3 "https://dl.k8s.io/release/$kv/bin/linux/amd64/kubectl.sha256")  /tmp/kubectl" | sha256sum -c -
  install -m 0755 /tmp/kubectl "$bin/kubectl"
}

install_cmdline_tools() {
  [ -x "$sdkmanager" ] && return
  local zip
  zip=$(curl -fsSL --retry 3 https://dl.google.com/android/repository/repository2-3.xml |
    python3 -c 'import sys, xml.etree.ElementTree as ET
r = ET.parse(sys.stdin).getroot()
p = next(p for p in r.iter("remotePackage") if p.get("path") == "cmdline-tools;latest")
print(next(a.find("complete/url").text for a in p.iter("archive") if a.findtext("host-os") == "linux"))')
  curl -fsSL --retry 3 -o /tmp/cmdline-tools.zip "https://dl.google.com/android/repository/$zip"
  rm -rf /tmp/cmdline-tools && unzip -q /tmp/cmdline-tools.zip -d /tmp
  mkdir -p "$sdk/cmdline-tools" && rm -rf "$sdk/cmdline-tools/latest"
  mv /tmp/cmdline-tools "$sdk/cmdline-tools/latest"
}

# platform-tools, then the NDKs and the compile platform in one sdkmanager call.
# Flutter's NDK version is read from its source at the pinned tag, so this need
# not wait for the Flutter checkout; finish_ndks covers a failed fetch.
install_android() {
  install_jdk &
  local jdk_job=$!
  install_cmdline_tools
  wait "$jdk_job"

  # Separately and first, so adb (tools/emu) works even if an NDK install fails.
  "$sdkmanager" platform-tools >/dev/null
  ln -sf "$sdk/platform-tools/adb" "$bin/adb"

  local flutter_ndk api
  flutter_ndk=$(curl -fsSL --retry 3 \
    "https://raw.githubusercontent.com/flutter/flutter/$flutter_version/$flutter_ext" |
    ndk_versions) || flutter_ndk=""
  mapfile -t ndks < <({ echo "$flutter_ndk"; ndk_versions "$repo/android/build.gradle"; } | sed '/^$/d' | sort -u)
  # Gradle's SDK installer fails on the current catalog, so install the compile
  # platform here too. Newer platforms carry a minor version (android-37.0).
  api=$(sed -n 's/^ *compileSdk *\([0-9]*\).*/\1/p' "$repo/android/app/build.gradle" | head -1)
  "$sdkmanager" "${ndks[@]/#/ndk;}" "${build_packages[@]}" "platforms;android-$api.0" >/dev/null ||
    "$sdkmanager" "${ndks[@]/#/ndk;}" "${build_packages[@]}" "platforms;android-$api" >/dev/null
}

install_flutter() {
  local action="$repo/.github/actions/setup-flutter/action.yml" fvm_version fvm_sha
  fvm_version=$(sed -n 's/^ *FVM_VERSION: *"\(.*\)"/\1/p' "$action")
  if [ "$(/opt/fvm/fvm --version 2>/dev/null)" != "$fvm_version" ]; then
    fvm_sha=$(sed -n 's/^ *FVM_SHA256_LINUX_X64: *//p' "$action")
    curl -fsSL --retry 3 -o /tmp/fvm.tar.gz \
      "https://github.com/leoafarias/fvm/releases/download/$fvm_version/fvm-$fvm_version-linux-x64.tar.gz"
    echo "$fvm_sha  /tmp/fvm.tar.gz" | sha256sum -c -
    rm -rf /opt/fvm && tar -xzf /tmp/fvm.tar.gz -C /opt
    ln -sf /opt/fvm/fvm "$bin/fvm"
  fi

  cd "$repo/common"
  # An explicit version keeps fvm from rewriting .fvmrc.
  fvm install "$flutter_version"
  fvm flutter config --android-sdk "$sdk" >/dev/null
  fvm flutter precache --android

  local flutter_root
  flutter_root=$(fvm flutter --version --machine | jq -r .flutterRoot)
  ln -sf "$flutter_root/bin/flutter" "$bin/flutter"
  ln -sf "$flutter_root/bin/dart" "$bin/dart"
}

# Installs an NDK the Flutter checkout pins that install_android missed, e.g.
# when GitHub was unreachable. A no-op when everything is in place.
finish_ndks() {
  local flutter_root missing=()
  flutter_root=$(readlink -f "$bin/flutter" | sed 's#/bin/flutter$##')
  for v in $(ndk_versions "$flutter_root/$flutter_ext"); do
    [ -d "$sdk/ndk/$v" ] || missing+=("ndk;$v")
  done
  [ ${#missing[@]} -eq 0 ] || "$sdkmanager" "${missing[@]}" >/dev/null
}

grep -qs '^sdk.dir=' "$repo/android/local.properties" || echo "sdk.dir=$sdk" >>"$repo/android/local.properties"

# Maven Central rate-limits the shared cloud egress IP; Google's mirror does not.
mkdir -p "$HOME/.gradle/init.d"
cat >"$HOME/.gradle/init.d/maven-mirror.gradle" <<'EOF'
// The Plugin Portal redirects to Maven Central, so the mirror and Google Maven
// go first wherever plugins and build classpaths resolve, and the mirror
// replaces Central elsewhere.
def mirrorUrl = 'https://maven-central.storage-download.googleapis.com/maven2/'
def rewrite = { handler ->
  handler.withType(MavenArtifactRepository).configureEach { repo ->
    if (repo.url.toString().startsWith('https://repo.maven.apache.org/')) {
      repo.url = mirrorUrl
    }
  }
}
beforeSettings { settings ->
  settings.pluginManagement.repositories.maven { url = mirrorUrl }
  settings.pluginManagement.repositories.google()
  settings.pluginManagement.repositories.gradlePluginPortal()
  rewrite(settings.pluginManagement.repositories)
  rewrite(settings.dependencyResolutionManagement.repositories)
  settings.gradle.allprojects {
    buildscript.repositories.maven { url = mirrorUrl }
    rewrite(buildscript.repositories)
    rewrite(repositories)
  }
}
EOF

# Each chain's output is prefixed with its name, since the chains interleave.
run() { # run <name> <function>
  "$2" 2>&1 | sed -u "s/^/[$1] /"
}

run android install_android &
android_job=$!
run flutter install_flutter &
flutter_job=$!
run kubectl install_kubectl &
kubectl_job=$!

failed=()
wait "$android_job" || failed+=(android)
wait "$flutter_job" || failed+=(flutter)
wait "$kubectl_job" || failed+=(kubectl)
if [ ${#failed[@]} -gt 0 ]; then
  echo "cloud-setup: failed: ${failed[*]}" >&2
  exit 1
fi

run ndk finish_ndks
