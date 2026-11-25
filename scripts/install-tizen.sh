#!/bin/bash
# Installs RuvBeint.wgt on a Samsung TV in Developer Mode.
# On the TV: Apps -> press 1 2 3 4 5 -> Developer mode ON, Host PC IP = this Mac's IP, reboot TV.
# Usage: scripts/install-tizen.sh TV_IP
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TV="${1:?Usage: $0 TV_IP}"
TS="${TIZEN_STUDIO:-$HOME/tizen-studio}"
SDB="$TS/tools/sdb"; TIZEN="$TS/tools/ide/bin/tizen"
"$SDB" connect "$TV"
SERIAL="$("$SDB" devices | awk -v ip="$TV" 'index($1,ip)==1{print $1}' | head -1)"
[ -n "$SERIAL" ] || { echo "Could not connect to $TV (is Developer Mode on with this Mac's IP?)"; exit 1; }
"$TIZEN" install -s "$SERIAL" -n "$ROOT/RuvBeint.wgt"
"$TIZEN" run -s "$SERIAL" -p RuvBeint00.RuvBeint || true
echo "Installed on $TV"
