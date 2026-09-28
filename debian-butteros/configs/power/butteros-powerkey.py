#!/usr/bin/env python3
# ADD-ON: phone hardware keys (stdlib only; runs as root via butteros-powerkey.service).
#   power short press      -> screen off/on (butteros-screen toggle)
#   power long press       -> left to logind (HandlePowerKeyLongPress=poweroff)
#   volume up / down       -> +/-5% volume (ignored while the screen is off)
#   power + volume down    -> screenshot to ~butter/Pictures (grim)
# Devices by name: pm8941_pwrkey (power), pm8941_resin (volume down), gpio-keys (volume up).
import glob, os, select, struct, subprocess, time

EV_KEY = 1
KEY_POWER, KEY_VOLUMEDOWN, KEY_VOLUMEUP = 116, 114, 115
FMT = 'llHHi'
SIZE = struct.calcsize(FMT)
LONG_PRESS = 1.5
WANTED = ('pm8941_pwrkey', 'pm8941_resin', 'gpio-keys')
USER_ENV = ['env', 'XDG_RUNTIME_DIR=/run/user/1000', 'WAYLAND_DISPLAY=wayland-0',
            'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus']

def as_butter(cmd, timeout=6):
    try:
        subprocess.run(['runuser', '-u', 'butter', '--'] + USER_ENV + cmd, timeout=timeout,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def screen_off():
    # real backlight state (the marker file alone could be stale)
    try:
        return open('/sys/class/backlight/backlight/bl_power').read().strip() != '0'
    except OSError:
        return os.path.exists('/run/butteros-screen-off')

def open_devices():
    fds = {}
    for d in sorted(glob.glob('/sys/class/input/event*')):
        try:
            name = open(d + '/device/name').read().strip()
        except OSError:
            continue
        if name in WANTED:
            try:
                fds[os.open('/dev/input/' + os.path.basename(d), os.O_RDONLY)] = name
            except OSError:
                pass
    return fds

# ADD-ON: double-tap to wake. While the screen is off the touchscreen is GRABBED (EVIOCGRAB),
# so apps/compositor get no touches; two taps within 0.4 s turn the screen on and release it.
import fcntl
EVIOCGRAB = 0x40044590
BTN_TOUCH = 330
TOUCH_NAMES = ('nt36672a-ts', 'NVT-ts', 'fts_ts')
touch = {'fd': None, 'last_tap': 0.0}

def touch_grab(on):
    if on and touch['fd'] is None:
        for d in sorted(glob.glob('/sys/class/input/event*')):
            try:
                if open(d + '/device/name').read().strip() in TOUCH_NAMES:
                    fd = os.open('/dev/input/' + os.path.basename(d), os.O_RDONLY | os.O_NONBLOCK)
                    fcntl.ioctl(fd, EVIOCGRAB, 1)
                    touch['fd'] = fd
                    break
            except OSError:
                pass
    elif not on and touch['fd'] is not None:
        try:
            fcntl.ioctl(touch['fd'], EVIOCGRAB, 0); os.close(touch['fd'])
        except OSError:
            pass
        touch['fd'] = None

def screenshot():
    stamp = time.strftime('%Y%m%d-%H%M%S')
    as_butter(['sh', '-c', f'mkdir -p ~/Pictures && grim ~/Pictures/Screenshot-{stamp}.png && '
               f'notify-send Screenshot "Saved Screenshot-{stamp}.png"'])

def shell_js(js):
    # run JS in the ButterOS shell page (power menu / volume OSD); never block the key loop
    try:
        subprocess.Popen(['timeout', '5', '/usr/local/bin/butteros-cdp', 'eval', js],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def volume(step):
    # change volume, then show the animated OSD with the new level (in the background)
    cmd = (f"wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ {step}; "
           "v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@); "
           "p=$(echo \"$v\" | awk '{printf \"%d\", $2*100}'); m=$(echo \"$v\" | grep -q MUTED && echo true || echo false); "
           # over an app too: butteros-gesture snapshots the app and shows the OSD on top of it
           "/usr/local/bin/butteros-gesture volume $p $m")
    try:
        subprocess.Popen(['runuser', '-u', 'butter', '--'] + USER_ENV + ['sh', '-c', cmd],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

MENU_HOLD = 1.0      # hold power this long -> power menu (logind no longer powers off on long press)

def power_menu():
    if screen_off():
        subprocess.run(['/usr/local/bin/butteros-screen', 'on'], timeout=10)
    as_butter(['wlrctl', 'toplevel', 'focus', 'title:Poco F1 ButterOS Shell'], timeout=3)
    shell_js('window.__openPowerMenu && window.__openPowerMenu()')

while True:
    fds = open_devices()
    if not fds:
        time.sleep(3)
        continue
    power_down_at = None
    voldown_held = False
    shot_taken = False
    try:
        menu_shown = False
        while True:
            # ADD-ON: long press opens the power menu while the key is still held
            if power_down_at is not None and not menu_shown and not shot_taken \
                    and time.monotonic() - power_down_at >= MENU_HOLD:
                menu_shown = True
                power_menu()
            touch_grab(screen_off())
            watch = list(fds) + ([touch['fd']] if touch['fd'] is not None else [])
            ready, _, _ = select.select(watch, [], [], 0.3)
            if touch['fd'] is not None and touch['fd'] in ready:
                ready.remove(touch['fd'])
                try:
                    data = os.read(touch['fd'], SIZE * 64)
                except OSError:
                    data = b''
                for off in range(0, len(data) - SIZE + 1, SIZE):
                    _, _, etype, code, value = struct.unpack(FMT, data[off:off + SIZE])
                    if etype == EV_KEY and code == BTN_TOUCH and value == 1:
                        now = time.monotonic()
                        if now - touch['last_tap'] < 0.4:
                            touch['last_tap'] = 0.0
                            subprocess.run(['/usr/local/bin/butteros-screen', 'on'], timeout=10)
                            touch_grab(False)
                            break
                        touch['last_tap'] = now
            for fd in ready:
                data = os.read(fd, SIZE * 16)
                for off in range(0, len(data) - SIZE + 1, SIZE):
                    _, _, etype, code, value = struct.unpack(FMT, data[off:off + SIZE])
                    if etype != EV_KEY:
                        continue
                    if code == KEY_VOLUMEDOWN:
                        voldown_held = value != 0
                        if value == 1 and power_down_at is not None and not shot_taken:
                            shot_taken = True; screenshot()
                        elif value in (1, 2) and power_down_at is None and not screen_off():
                            volume('5%-')
                    elif code == KEY_VOLUMEUP and value in (1, 2) and not screen_off():
                        volume('5%+')
                    elif code == KEY_POWER:
                        if value == 1:
                            power_down_at = time.monotonic(); shot_taken = False; menu_shown = False
                            if voldown_held and not screen_off():
                                shot_taken = True; screenshot()
                        elif value == 0 and power_down_at is not None:
                            held = time.monotonic() - power_down_at
                            power_down_at = None
                            if held < LONG_PRESS and not shot_taken and not menu_shown:
                                subprocess.run(['/usr/local/bin/butteros-screen', 'toggle'], timeout=10)
    except OSError:
        for fd in fds:
            try: os.close(fd)
            except OSError: pass
        time.sleep(2)
