#!/bin/sh
# ==============================================================================
# ADD-ON: ButterOS boot animation (video + sound), played straight to the display with mpv
# (DRM, no compositor) as early as the display exists, BEFORE the labwc shell starts.
# When the video ends, the final logo frame is written into the framebuffer, so the logo
# stays on screen (instead of console text / black) until the shell draws its first frame.
# Sound goes directly to ALSA; waits up to 8 s for the sound card (DSP boots in parallel).
# Hard 20 s cap so boot can never hang here.
# ==============================================================================
VIDEO=/usr/share/butteros/bootanimation.mp4
LOGO=/usr/share/butteros/bootlogo.bgra.gz
LOG=/run/butteros-bootanim.log
log() { echo "$(cut -d' ' -f1 /proc/uptime)s $*" >> $LOG; }

# hide the console cursor / text behind us
echo 0 > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null
printf '\033[?25l\033[2J' > /dev/tty1 2>/dev/null

show_logo() {
    # framebuffer must be 1080 px wide, 32 bpp (stride 4320) - otherwise skip (never garble)
    [ -f "$LOGO" ] || return
    bpp=$(cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null)
    stride=$(cat /sys/class/graphics/fb0/stride 2>/dev/null)
    [ "$bpp" = 32 ] || return
    # rows are 1080*4 = 4320 bytes; the panel's framebuffer pads each row to $stride (4352 here)
    python3 - "$LOGO" "$stride" <<'PY' && log "logo held on fb0 (stride $stride)"
import gzip, sys
src, stride = sys.argv[1], int(sys.argv[2])
row, pad = 1080 * 4, b''
pad = bytes(max(0, stride - row))
with gzip.open(src, 'rb') as f, open('/dev/fb0', 'wb') as fb:
    while True:
        r = f.read(row)
        if len(r) < row:
            break
        fb.write(r + pad)
PY
}

[ -f "$VIDEO" ] && command -v mpv >/dev/null || { show_logo; exit 0; }

for i in $(seq 50); do [ -e /dev/dri/card0 ] && break; sleep 0.1; done
log "display ready"

AUDIO="--no-audio"
for i in $(seq 80); do grep -qi "poco\|beryllium" /proc/asound/cards 2>/dev/null && break; sleep 0.1; done
if grep -qi "poco\|beryllium" /proc/asound/cards 2>/dev/null; then
    # Speaker route set directly (same switches as ucm2/Xiaomi/beryllium/HiFi.conf "HiFi" +
    # "Speaker1"); a one-shot alsaucm run didn't leave the route enabled -> silent boot.
    amixer -c 0 -q cset name='QUAT_MI2S_RX Audio Mixer MultiMedia1' 1 >>$LOG 2>&1
    amixer -c 0 -q cset name='Configuration' 4 >>$LOG 2>&1
    amixer -c 0 -q cset name='TAS2559 DAC Playback Volume' 35 >>$LOG 2>&1
    # small ALSA buffer: the q6 DSP path plays silence with mpv's default ~1 s buffer
    # (12000-frame periods); PipeWire - which is audible - uses 480-frame periods
    AUDIO="--ao=alsa --audio-device=alsa/plughw:0,0 --audio-buffer=0.06 --volume=100"
    log "audio: card ready"
else
    log "audio: no card after 8 s -> silent"
fi

timeout 15 mpv --no-config --really-quiet --no-terminal --no-input-default-bindings \
    --vo=drm --drm-connector=DSI-1 --hwdec=no --keep-open=no \
    $AUDIO "$VIDEO" >>$LOG 2>&1 &
MPV=$!
# The TAS2559 amp loads its tuning profile when the stream powers up, and on this direct path it
# picked profile 3 = EARPIECE (quiet, top of phone) -> "no boot sound". Re-select profile 4 =
# SPEAKER once playback is running (dmesg then shows "..._s5_4"), and once more to be sure.
if [ "$AUDIO" != "--no-audio" ]; then
    sleep 0.6; amixer -c 0 -q cset name='Configuration' 4 >>$LOG 2>&1
    sleep 1.0; amixer -c 0 -q cset name='Configuration' 4 >>$LOG 2>&1
    log "amp: speaker profile selected"
fi
wait $MPV
log "mpv exit $?"
show_logo
exit 0
