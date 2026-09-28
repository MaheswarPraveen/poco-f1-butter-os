#!/usr/bin/env python3
# ADD-ON dev tool: make a copy of an Android boot image (header v0-v2) with a new kernel
# command line. The cmdline is a fixed 512-byte header field, so this edits it in place -
# kernel, ramdisk and DTB are untouched byte-for-byte.
#   python patch-bootimg-cmdline.py in.img out.img "new cmdline"
import struct, sys

src, dst, cmdline = sys.argv[1], sys.argv[2], sys.argv[3]
data = bytearray(open(src, 'rb').read())
assert data[:8] == b'ANDROID!', 'not an Android boot image'
ver = struct.unpack_from('<I', data, 40)[0]
assert ver <= 2, f'header v{ver} not supported'
raw = cmdline.encode()
assert len(raw) < 512, 'cmdline too long for the 512-byte field'
old = data[64:576].split(b'\0')[0].decode()
data[64:576] = raw + b'\0' * (512 - len(raw))
open(dst, 'wb').write(data)
print('old:', old)
print('new:', cmdline)
