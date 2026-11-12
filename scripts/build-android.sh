#!/bin/bash
# Builds the signed Android TV APK -> ../RuvBeint.apk
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/android"
if [ -z "${ANDROID_HOME:-}" ]; then
  for d in "$HOME/Library/Android/sdk" "$HOME/Android/Sdk" /opt/android; do
    [ -d "$d" ] && export ANDROID_HOME="$d" && break
  done
fi
[ -n "${ANDROID_HOME:-}" ] || { echo "Android SDK not found. Install Android Studio or set ANDROID_HOME."; exit 1; }
echo "sdk.dir=$ANDROID_HOME" > local.properties
# Needs JDK 17+ (Android Studio's bundled JBR works).
if [ -z "${JAVA_HOME:-}" ] && [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi
./gradlew assembleRelease
cp app/build/outputs/apk/release/app-release.apk "$ROOT/RuvBeint.apk"
echo "Built: $ROOT/RuvBeint.apk"
