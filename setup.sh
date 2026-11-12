#!/bin/bash
# Finds the Google TV on the home network and installs RÚV Beint.
# Usage: ./setup.sh [TV_IP[:PORT]]   (scans the local /24 if no IP is given)
cd "$(dirname "$0")"
LOG="$PWD/setup.log"
exec > >(tee "$LOG") 2>&1
echo "== RÚV Beint setup $(date) =="

ADB=""
for c in "$(command -v adb)" "$HOME/Library/Android/sdk/platform-tools/adb" /opt/homebrew/bin/adb /usr/local/bin/adb "$PWD/platform-tools/adb"; do
  [ -n "$c" ] && [ -x "$c" ] && ADB="$c" && break
done
if [ -z "$ADB" ]; then
  echo "adb not found, downloading platform-tools from Google…"
  curl -sSLo pt.zip https://dl.google.com/android/repository/platform-tools-latest-darwin.zip && unzip -qo pt.zip && rm pt.zip
  ADB="$PWD/platform-tools/adb"
fi
echo "adb: $ADB"; "$ADB" version | head -1
"$ADB" start-server >/dev/null 2>&1

MYIP=""
for i in en0 en1 en2 en3 en4 en5 en6 en7 en8; do MYIP=$(ipconfig getifaddr $i 2>/dev/null) && [ -n "$MYIP" ] && break; done
echo "Mac IP: $MYIP"
NET=${MYIP%.*}

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo "Scanning $NET.0/24 for adb (port 5555)…"
  HITS=$(for i in $(seq 1 254); do (nc -z -G 1 $NET.$i 5555 >/dev/null 2>&1 && echo $NET.$i) & done; wait)
  echo "Found: ${HITS:-nothing}"
  echo "mDNS:"; "$ADB" mdns services 2>/dev/null
  for h in $HITS; do "$ADB" connect $h:5555; done
else
  "$ADB" connect "$TARGET"
fi

echo "Waiting for approval on the TV (choose 'Allow')…"
for t in $(seq 1 30); do
  DEV=$("$ADB" devices | awk 'NR>1 && $2=="device"{print $1}' | head -1)
  [ -n "$DEV" ] && break
  sleep 2
done
"$ADB" devices -l
if [ -z "$DEV" ]; then echo "ERROR: no device connected."; exit 1; fi
echo "Device: $DEV ($("$ADB" -s $DEV shell getprop ro.product.model))"
"$ADB" -s "$DEV" install -r RuvBeint.apk && \
"$ADB" -s "$DEV" shell monkey -p is.steinar.ruvbeint -c android.intent.category.LEANBACK_LAUNCHER 1 >/dev/null 2>&1 && \
echo "DONE: RÚV Beint installed and launched."
