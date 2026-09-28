#!/usr/bin/env python3
# ==============================================================================
# ADD-ON: ButterOS boot menu (GRUB-style) - runs right after Linux starts, BEFORE the boot
# animation, drawn straight to the framebuffer (no compositor yet).
#   ButterOS (default after 3 s)  |  Android (Clover OS)
#   Volume up/down = choose, Power = start, or tap an option.
# Android: butteros-boot-switch writes the stock Clover OS boot image (verified) and reboots
# into it (the Poco F1 bootloader can only start Android from the boot partition).
# Skipped entirely if the Android image isn't installed. Any error -> continue to ButterOS.
# ==============================================================================
import fcntl, glob, gzip, os, select, struct, subprocess, sys, time

FRAMES = '/usr/share/butteros/bootmenu'
ANDROID_IMG = '/usr/share/butteros/boot-images/android-boot.img'
SWITCH = '/usr/local/bin/butteros-boot-switch'
BOXES_Y = [(900, 1120), (1180, 1400)]            # option boxes in panel pixels (render-bootmenu.py)
FMT = 'llHHi'; SIZE = struct.calcsize(FMT)
EV_KEY, EV_ABS = 1, 3
KEY_POWER, KEY_VOLDOWN, KEY_VOLUP, BTN_TOUCH = 116, 114, 115, 330
ABS_MT_POSITION_Y = 0x36
EVIOCGRAB = 0x40044590
COUNTDOWN = 8          # seconds before ButterOS starts by itself; any key/touch stops it

def log(msg):
    try:
        with open('/run/butteros-bootmenu.log', 'a') as f:
            f.write(f'{time.monotonic():.2f} {msg}\n')
    except OSError:
        pass

def show(name):
    try:
        stride = int(open('/sys/class/graphics/fb0/stride').read())
        pad = bytes(max(0, stride - 1080 * 4))
        with gzip.open(f'{FRAMES}/{name}.bgra.gz', 'rb') as src, open('/dev/fb0', 'wb') as fb:
            row = 1080 * 4
            while True:
                r = src.read(row)
                if len(r) < row:
                    break
                fb.write(r + pad)
    except OSError as e:
        log(f'draw {name}: {e}')

def blank():
    # menu runs AFTER the boot animation: put the held boot logo back, so the logo stays on
    # screen until the shell fades in (black only if the logo file is missing)
    try:
        stride = int(open('/sys/class/graphics/fb0/stride').read())
        pad = bytes(max(0, stride - 1080 * 4))
        with gzip.open('/usr/share/butteros/bootlogo.bgra.gz', 'rb') as src, open('/dev/fb0', 'wb') as fb:
            while True:
                r = src.read(1080 * 4)
                if len(r) < 1080 * 4:
                    break
                fb.write(r + pad)
    except OSError:
        try:
            with open('/dev/fb0', 'wb') as fb:
                fb.write(bytes(int(open('/sys/class/graphics/fb0/stride').read()) * 2246))
        except OSError:
            pass

def open_inputs():
    fds, touch_scale = {}, None
    for d in sorted(glob.glob('/sys/class/input/event*')):
        try:
            name = open(d + '/device/name').read().strip()
        except OSError:
            continue
        if name not in ('pm8941_pwrkey', 'pm8941_resin', 'gpio-keys', 'nt36672a-ts'):
            continue
        try:
            fd = os.open('/dev/input/' + os.path.basename(d), os.O_RDONLY | os.O_NONBLOCK)
            fcntl.ioctl(fd, EVIOCGRAB, 1)
            fds[fd] = name
            if name == 'nt36672a-ts':
                buf = bytearray(24)                     # struct input_absinfo
                fcntl.ioctl(fd, 0x80184540 + ABS_MT_POSITION_Y, buf, True)
                ymax = struct.unpack('iiiiii', buf)[2]
                touch_scale = 2246 / max(1, ymax)
        except OSError as e:
            log(f'input {name}: {e}')
    return fds, touch_scale or 1.0

def main():
    if not (os.path.exists(ANDROID_IMG) and os.path.exists(SWITCH) and os.path.exists('/dev/fb0')):
        log('android image / switch / fb missing -> no menu'); return 0
    for _ in range(50):                                   # input devices may still be probing
        if glob.glob('/dev/input/event*'): break
        time.sleep(0.1)
    fds, tscale = open_inputs()
    sel, counting, t_start, last_count = 0, True, time.monotonic(), None
    touch_y, touch_down = None, False
    show(f'sel0_t{COUNTDOWN}')
    deadline = time.monotonic() + 30
    choice = None
    while choice is None and time.monotonic() < deadline:
        if counting:
            left = COUNTDOWN - int(time.monotonic() - t_start)
            if left <= 0:
                choice = 0; break
            if left != last_count:
                show(f'sel{sel}_t{left}'); last_count = left
        ready, _, _ = select.select(list(fds), [], [], 0.1)
        for fd in ready:
            try:
                data = os.read(fd, SIZE * 64)
            except OSError:
                continue
            for off in range(0, len(data) - SIZE + 1, SIZE):
                _, _, et, code, val = struct.unpack(FMT, data[off:off + SIZE])
                if et == EV_ABS and code == ABS_MT_POSITION_Y:
                    touch_y = val * tscale
                elif et == EV_KEY and val == 1 and code in (KEY_VOLUP, KEY_VOLDOWN):
                    counting = False
                    sel = 0 if code == KEY_VOLUP else 1
                    show(f'sel{sel}')
                elif et == EV_KEY and code == KEY_POWER and val == 0:
                    choice = sel
                elif et == EV_KEY and code == BTN_TOUCH:
                    if val == 1:
                        touch_down = True
                        if counting:                      # a touch anywhere stops the countdown
                            counting = False; show(f'sel{sel}')
                    elif touch_down and touch_y is not None:
                        touch_down = False
                        for i, (y0, y1) in enumerate(BOXES_Y):
                            if y0 <= touch_y <= y1:
                                sel = i; show(f'sel{sel}'); choice = i
    for fd in fds:
        try:
            fcntl.ioctl(fd, EVIOCGRAB, 0); os.close(fd)
        except OSError:
            pass
    choice = 0 if choice is None else choice
    log(f'choice {"android" if choice == 1 else "butteros"}')
    if choice == 1:
        show('sel1')
        r = subprocess.run([SWITCH, 'android'], capture_output=True, text=True, timeout=60)
        log('switch: ' + (r.stdout + r.stderr).strip().replace('\n', ' | '))
        # only returns if the switch failed (success reboots) -> carry on into ButterOS
    blank()
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as e:
        log(f'error: {e!r} -> ButterOS')
        sys.exit(0)
