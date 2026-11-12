#!/bin/bash
# Builds the signed Samsung Tizen widget -> ../RuvBeint.wgt
# Needs Tizen Studio (CLI is enough): https://developer.tizen.org/development/tizen-studio/download
# Signs with the author cert in tizen/certs (keep it: updates must use the same author cert)
# and the public Tizen distributor cert. Newer Samsung TVs may require a Samsung
# distributor certificate instead; set TIZEN_PROFILE to a profile created in
# Tizen Studio's Certificate Manager to use it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TS="${TIZEN_STUDIO:-$HOME/tizen-studio}"
TIZEN="$TS/tools/ide/bin/tizen"
[ -x "$TIZEN" ] || { echo "Tizen Studio not found at $TS (set TIZEN_STUDIO)"; exit 1; }
DATA="${TIZEN_STUDIO_DATA:-$HOME/tizen-studio-data}"
PROFILE="${TIZEN_PROFILE:-RuvBeint}"
AUTHOR_PW="ruvbeint123"

if [ "$PROFILE" = "RuvBeint" ]; then
  # Write the profile directly with plain passwords (the CLI's password store
  # fails on headless machines).
  DIST="$TS/tools/certificate-generator/certificates/distributor"
  mkdir -p "$DATA/profile"
  cat > "$DATA/profile/profiles.xml" <<XML
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<profiles active="RuvBeint" version="3.1">
<profile name="RuvBeint">
<profileitem ca="" distributor="0" key="$ROOT/tizen/certs/ruvbeint-author.p12" password="$AUTHOR_PW" rootca=""/>
<profileitem ca="$DIST/tizen-distributor-ca.cer" distributor="1" key="$DIST/tizen-distributor-signer.p12" password="tizenpkcs12passfordsigner" rootca=""/>
<profileitem ca="" distributor="2" key="" password="" rootca=""/>
</profile>
</profiles>
XML
  "$TIZEN" cli-config "profiles.path=$DATA/profile/profiles.xml" >/dev/null
fi

BUILD="$(mktemp -d)"
cp "$ROOT"/tizen/{config.xml,index.html,main.js,icon.png} "$BUILD/"
"$TIZEN" package -t wgt -s "$PROFILE" -- "$BUILD"
mv "$BUILD"/*.wgt "$ROOT/RuvBeint.wgt"
rm -rf "$BUILD"
echo "Built: $ROOT/RuvBeint.wgt"
