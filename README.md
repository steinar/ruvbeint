# RÚV Beint

Opens RÚV's live broadcast straight away on the TV – no menus.

| Remote key            | Action                        |
|-----------------------|-------------------------------|
| Up / Down, CH+ / CH−  | Switch RÚV ↔ RÚV 2            |
| OK / CC               | Icelandic subtitles on/off    |
| Left / Right / Info   | Show channel and subtitle state |
| Back                  | Exit                          |

The stream URL is looked up at start from RÚV's player API
(`https://geo.spilari.ruv.is/channel/ruv` / `ruv2`), with the current HLS URL
built in as a fallback. Streams are geo-blocked to Iceland.

## Layout

    android/   Android TV / Google TV app (Java, Media3 ExoPlayer)
    tizen/     Samsung Tizen web app (AVPlay)
    scripts/   build and install scripts
    setup.sh   finds the Google TV on the LAN and installs RuvBeint.apk
    RuvBeint.apk, RuvBeint.wgt   last built packages (git-ignored)

## Android TV / Google TV

    scripts/build-android.sh                 # -> RuvBeint.apk
    scripts/install-android.sh 192.168.181.210

Needs the Android SDK (Android Studio) and JDK 17+. Signing key:
`android/keystore/ruvbeint.jks` (password `ruvbeint`) – keep it, updates must
be signed with the same key. If `adb install` stalls (Mi Box 4 does),
use `scripts/install-android-python.py` (`pip3 install adb-shell`).

## Samsung (Tizen)

    scripts/build-tizen.sh                   # -> RuvBeint.wgt
    scripts/install-tizen.sh <TV_IP>

Needs Tizen Studio (CLI is enough) in `~/tizen-studio`. On the TV:
Apps → press 1 2 3 4 5 → Developer mode ON → Host PC IP = this Mac → reboot.
Author cert: `tizen/certs/ruvbeint-author.p12` (password `ruvbeint123`).
Newer Samsung TVs may reject the generic Tizen distributor cert; then create a
Samsung certificate in Tizen Studio's Certificate Manager (needs your Samsung
account and the TV's DUID) and build with `TIZEN_PROFILE=<profile name>`.
