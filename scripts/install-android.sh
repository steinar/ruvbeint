#!/bin/bash
# Installs RuvBeint.apk on an Android/Google TV over the network.
# Usage: scripts/install-android.sh [TV_IP]   (default 192.168.181.210)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TV="${1:-192.168.181.210}"
ADB="$(command -v adb || true)"
[ -z "$ADB" ] && [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ] && ADB="$HOME/Library/Android/sdk/platform-tools/adb"
[ -n "$ADB" ] || { echo "adb not found (brew install android-platform-tools)"; exit 1; }
"$ADB" connect "$TV:5555"
echo "Accept 'Allow USB debugging' on the TV if prompted…"
"$ADB" -s "$TV:5555" wait-for-device
"$ADB" -s "$TV:5555" install -r "$ROOT/RuvBeint.apk"
"$ADB" -s "$TV:5555" shell monkey -p is.steinar.ruvbeint -c android.intent.category.LEANBACK_LAUNCHER 1 >/dev/null
echo "Installed and launched on $TV"
