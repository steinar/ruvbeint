#!/usr/bin/env python3
"""Fallback Android TV installer that needs no adb binary (pip install adb-shell).
Streams the APK over the adb shell in base64 chunks, which also works on devices
(e.g. Mi Box 4) where adb's file push stalls.
Usage: install-android-python.py [TV_IP]"""
import base64, hashlib, os, sys
from adb_shell.adb_device import AdbDeviceTcp
from adb_shell.auth.keygen import keygen
from adb_shell.auth.sign_pythonrsa import PythonRSASigner

tv = sys.argv[1] if len(sys.argv) > 1 else '192.168.181.210'
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
key = os.path.expanduser('~/.android/adbkey_ruvbeint')
if not os.path.exists(key):
    os.makedirs(os.path.dirname(key), exist_ok=True)
    keygen(key)
signer = PythonRSASigner(open(key + '.pub').read(), open(key).read())
dev = AdbDeviceTcp(tv, 5555, default_transport_timeout_s=60.)
print('Connecting – accept "Allow USB debugging" on the TV if asked…')
dev.connect(rsa_keys=[signer], auth_timeout_s=120)
apk = open(os.path.join(root, 'RuvBeint.apk'), 'rb').read()
dst, tmp = '/data/local/tmp/rb.apk', '/data/local/tmp/rb.b64'
dev.shell(f'rm -f {dst} {tmp}')
b64 = base64.b64encode(apk).decode()
for i in range(0, len(b64), 30000):
    dev.shell(f"echo -n '{b64[i:i+30000]}' >> {tmp}", read_timeout_s=60)
dev.shell(f'base64 -d {tmp} > {dst}; rm {tmp}')
assert dev.shell(f'md5sum {dst}').split()[0] == hashlib.md5(apk).hexdigest(), 'checksum mismatch'
print(dev.shell(f'pm install -r {dst}', read_timeout_s=120).strip())
dev.shell(f'rm {dst}')
dev.shell('monkey -p is.steinar.ruvbeint -c android.intent.category.LEANBACK_LAUNCHER 1')
dev.close()
print('Done.')
