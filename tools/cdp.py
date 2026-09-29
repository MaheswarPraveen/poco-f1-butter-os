#!/usr/bin/env python3
# ADD-ON dev tool: minimal Chrome DevTools Protocol client (stdlib only) for the ButterOS kiosk.
#   cdp.py eval '<js expression>'     -> prints JSON result
#   cdp.py shot [scale] [quality]     -> prints base64 JPEG of the screen between markers
import base64, json, os, socket, struct, sys, urllib.request

def page_ws():
    tabs = json.load(urllib.request.urlopen('http://127.0.0.1:9222/json', timeout=5))
    for t in tabs:
        if t.get('type') == 'page' and 'butteros/shell.html' in t.get('url', ''):
            return t['webSocketDebuggerUrl']
    raise SystemExit('shell page not found')

class WS:
    def __init__(self, url):
        rest = url.split('://', 1)[1]
        hostport, path = rest.split('/', 1)
        host, port = hostport.split(':')
        self.s = socket.create_connection((host, int(port)), timeout=20)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f'GET /{path} HTTP/1.1\r\nHost: {hostport}\r\nUpgrade: websocket\r\n'
                        f'Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n').encode())
        buf = b''
        while b'\r\n\r\n' not in buf:
            buf += self.s.recv(4096)
        self.buf = buf.split(b'\r\n\r\n', 1)[1]

    def send(self, obj):
        data = json.dumps(obj).encode()
        hdr = bytearray([0x81])
        n = len(data)
        if n < 126: hdr.append(0x80 | n)
        elif n < 65536: hdr += bytes([0x80 | 126]) + struct.pack('>H', n)
        else: hdr += bytes([0x80 | 127]) + struct.pack('>Q', n)
        mask = os.urandom(4)
        hdr += mask
        self.s.sendall(bytes(hdr) + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def _read(self, n):
        while len(self.buf) < n:
            chunk = self.s.recv(65536)
            if not chunk: raise EOFError
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def recv(self):
        msg = b''
        while True:
            b1, b2 = self._read(2)
            n = b2 & 0x7f
            if n == 126: n = struct.unpack('>H', self._read(2))[0]
            elif n == 127: n = struct.unpack('>Q', self._read(8))[0]
            msg += self._read(n)
            if b1 & 0x80: return json.loads(msg)

def call(ws, method, params=None, _id=[0]):
    _id[0] += 1
    ws.send({'id': _id[0], 'method': method, 'params': params or {}})
    while True:
        m = ws.recv()
        if m.get('id') == _id[0]:
            return m

ws = WS(page_ws())
if sys.argv[1] == 'eval':
    r = call(ws, 'Runtime.evaluate', {'expression': sys.argv[2], 'returnByValue': True, 'awaitPromise': True})
    res = r.get('result', {})
    if 'exceptionDetails' in res:
        print('EXCEPTION', json.dumps(res['exceptionDetails'].get('exception', {}).get('description', res['exceptionDetails']))[:2000])
    else:
        print(json.dumps(res.get('result', {}).get('value'), indent=1)[:20000])
elif sys.argv[1] == 'shot':
    scale = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5
    q = int(sys.argv[3]) if len(sys.argv) > 3 else 45
    m = call(ws, 'Page.getLayoutMetrics')['result']['cssVisualViewport']
    r = call(ws, 'Page.captureScreenshot', {'format': 'jpeg', 'quality': q,
             'clip': {'x': 0, 'y': 0, 'width': m['clientWidth'], 'height': m['clientHeight'], 'scale': scale}})
    raw = base64.b64decode(r['result']['data'])
    import hashlib
    with open('/tmp/butteros-shot.jpg', 'wb') as f:
        f.write(raw)
    # the PC pulls /tmp/butteros-shot.jpg in small verified chunks (serial drops bytes on big bursts)
    print('__SHOT_MD5__ ' + hashlib.md5(raw).hexdigest() + ' ' + str(len(raw)))
