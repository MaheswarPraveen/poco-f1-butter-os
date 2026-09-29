#!/usr/bin/env python3
import http.server
import socketserver
import subprocess
import urllib.parse
import os
import json
import hmac

PORT = 9090

# ADD-ON (security): the bridge runs any shell command, and the user has passwordless sudo.
# Previously ANY web page open in Chromium could call it (CORS *), e.g. via <img src=".../exec?cmd=...">.
# Now every command needs the per-boot token that butteros-session generates and hands only to the
# shell page (URL fragment) - web pages can't know it. Requests from web origins are refused outright.
TOKEN = os.environ.get('BUTTEROS_BRIDGE_TOKEN', '')
OPEN_PATHS = ('/ping',)
# ADD-ON (haptics): navigator.vibrate() is a no-op in Chromium on Linux, so the shell's haptic
# "detents" never vibrated. Drive the PMI8998 vibrator (input device "spmi_haptics", force feedback)
# directly: upload an FF_RUMBLE effect per duration once, then play it (EV_FF). Device kept open.
import glob, struct, threading
try:
    import fcntl
except ImportError:          # not on Linux (PC-side testing)
    fcntl = None
_hap = {'fd': None, 'effects': {}, 'lock': threading.Lock()}
_FF_RUMBLE, _EV_FF = 0x50, 0x15
_EVIOCSFF = 0x40304580            # _IOW('E', 0x80, struct ff_effect) with sizeof(ff_effect)=48 on arm64

def _haptic_fd():
    if _hap['fd'] is None:
        for d in glob.glob('/sys/class/input/event*'):
            try:
                if 'haptic' in open(d + '/device/name').read().lower():
                    _hap['fd'] = os.open('/dev/input/' + os.path.basename(d), os.O_RDWR)
                    break
            except OSError:
                pass
    return _hap['fd']

def haptic(ms):
    ms = max(5, min(int(ms), 400))
    with _hap['lock']:
        fd = _haptic_fd() if fcntl else None
        if fd is None:
            return False
        eid = _hap['effects'].get(ms)
        if eid is None:
            # struct ff_effect: type, id, direction, trigger{button,interval}, replay{length,delay},
            # pad to 16, union(32 bytes): rumble{strong_magnitude, weak_magnitude}
            buf = bytearray(struct.pack('HhHHHHH2x', _FF_RUMBLE, -1, 0, 0, 0, ms, 0) + struct.pack('HH', 0xC000, 0x8000) + bytes(28))
            try:
                fcntl.ioctl(fd, _EVIOCSFF, buf, True)
            except OSError:
                return False
            eid = struct.unpack_from('h', buf, 2)[0]
            _hap['effects'][ms] = eid
        try:
            os.write(fd, struct.pack('llHHi', 0, 0, _EV_FF, eid, 1))
            return True
        except OSError:
            _hap['fd'] = None; _hap['effects'].clear()
            return False

NOTIF_LOG = '/run/user/1000/butteros-notifs.jsonl'   # written by butteros-notifyd
WAKE_FILE = '/run/butteros-wake'                       # bumped by butteros-screen on

def get_runtime_env():
    env = os.environ.copy()
    wayland_disp = env.get('WAYLAND_DISPLAY', 'wayland-0')
    env['WAYLAND_DISPLAY'] = wayland_disp

    # Find the actual directory containing wayland socket
    uid = os.getuid() if hasattr(os, 'getuid') else 1000
    candidates = ['/run/user/1000', f'/run/user/{uid}', '/run/user/0', '/tmp']
    for c in candidates:
        if os.path.exists(os.path.join(c, wayland_disp)) or os.path.exists(c):
            env['XDG_RUNTIME_DIR'] = c
            break

    if 'PULSE_SERVER' not in env and os.path.exists('/run/user/1000/pulse/native'):
        env['PULSE_SERVER'] = 'unix:/run/user/1000/pulse/native'

    return env

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True

class BridgeHandler(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', 'null')   # ADD-ON: file:// shell only (was *)
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()

    # ADD-ON (security): refuse web origins; require the session token for everything but /ping
    def _authorized(self, parsed, params):
        origin = self.headers.get('Origin')
        if origin not in (None, 'null', 'file://'):
            return False
        if parsed.path in OPEN_PATHS or not TOKEN:
            return True
        return hmac.compare_digest(params.get('t', [''])[0], TOKEN)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        if not self._authorized(parsed, params):
            self.send_json({'status': 403, 'error': 'forbidden'}, code=403)
            return

        # ADD-ON: notifications posted by apps (butteros-notifyd), newer than ?since=<id>
        if parsed.path == '/notifs':
            since = int(params.get('since', ['0'])[0] or 0)
            items = []
            try:
                with open(NOTIF_LOG) as f:
                    for line in f.readlines()[-200:]:
                        try:
                            n = json.loads(line)
                            if n.get('seq', 0) > since:
                                items.append(n)
                        except ValueError:
                            pass
            except OSError:
                pass
            self.send_json({'status': 0, 'items': items})
            return

        # ADD-ON: real vibration (see haptic())
        if parsed.path == '/haptic':
            ok = haptic(params.get('ms', ['20'])[0] or 20)
            self.send_json({'status': 0 if ok else 1})
            return

        # ADD-ON: screen state for the lock screen (wake counter bumps on every screen-on)
        if parsed.path == '/state':
            try:
                wake = int(open(WAKE_FILE).read().strip() or 0)
            except (OSError, ValueError):
                wake = 0
            self.send_json({'status': 0, 'wake': wake, 'screen': 'off' if os.path.exists('/run/butteros-screen-off') else 'on'})
            return

        if parsed.path == '/launch':
            cmd = params.get('cmd', [''])[0]
            if cmd:
                try:
                    env = get_runtime_env()
                    # Detach process to prevent zombie retention and FD sharing
                    subprocess.Popen(
                        cmd,
                        shell=True,
                        env=env,
                        stdin=subprocess.DEVNULL,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        start_new_session=True
                    )
                    self.send_json({'status': 0, 'message': 'launched', 'cmd': cmd})
                    return
                except Exception as e:
                    self.send_json({'status': 1, 'error': str(e)})
                    return
            else:
                self.send_json({'status': 1, 'error': 'missing cmd parameter'}, code=400)
                return

        elif parsed.path == '/exec':
            cmd = params.get('cmd', [''])[0]
            if cmd:
                try:
                    env = get_runtime_env()
                    res = subprocess.run(
                        cmd,
                        shell=True,
                        env=env,
                        capture_output=True,
                        text=True,
                        # ADD-ON: optional &timeout= (Bluetooth pairing / scans need longer), max 60 s
                        timeout=max(1, min(60, int(params.get('timeout', ['15'])[0] or 15)))
                    )
                    out = (res.stdout or '') + (res.stderr or '')
                    self.send_json({'status': res.returncode, 'output': out})
                    return
                except subprocess.TimeoutExpired:
                    self.send_json({'status': -1, 'output': 'Command timed out'})
                    return
                except Exception as e:
                    self.send_json({'status': -1, 'output': str(e)})
                    return
            else:
                self.send_json({'status': 1, 'error': 'missing cmd parameter'}, code=400)
                return

        elif parsed.path == '/ping':
            self.send_json({'status': 0, 'message': 'ButterOS Bridge Active'})
            return

        self.send_json({'status': 404, 'error': 'not found'}, code=404)

    def send_json(self, data, code=200):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', 'null')  # ADD-ON: file:// shell only (was *)
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    with ThreadedTCPServer(('127.0.0.1', PORT), BridgeHandler) as httpd:
        print(f"ButterOS Threaded Bridge listening on 127.0.0.1:{PORT}")
        httpd.serve_forever()
