#!/usr/bin/env python3
# ADD-ON dev tool: pre-render the ButterOS boot menu frames (1080x2246, raw BGRA, gzipped) for
# butteros-bootmenu, which draws them straight to the framebuffer before any compositor runs.
# Frames: sel{0,1}_t{3,2,1} (countdown running) and sel{0,1} (user is choosing).
import gzip, os, sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else 'bootmenu'
os.makedirs(OUT, exist_ok=True)
W, H = 1080, 2246
GOLD, CREAM, MUTED = (222, 176, 86), (245, 240, 230), (140, 133, 120)
F = r'C:\Windows\Fonts'
f_title = ImageFont.truetype(os.path.join(F, 'segoeuisl.ttf'), 64)
f_opt = ImageFont.truetype(os.path.join(F, 'segoeuib.ttf'), 60)
f_sub = ImageFont.truetype(os.path.join(F, 'segoeui.ttf'), 36)
f_hint = ImageFont.truetype(os.path.join(F, 'segoeui.ttf'), 34)

# option boxes (also used by the runtime for tap hit-testing: y ranges below)
BOXES = [(110, 900, 970, 1120), (110, 1180, 970, 1400)]
OPTS = [('ButterOS', 'Linux phone'), ('Android', 'Clover OS')]

def ctext(d, y, s, font, fill):
    w = d.textlength(s, font=font)
    d.text(((W - w) / 2, y), s, font=font, fill=fill)

def frame(sel, count):
    im = Image.new('RGB', (W, H), (0, 0, 0))
    d = ImageDraw.Draw(im)
    ctext(d, 560, 'Choose system', f_title, CREAM)
    for i, (box, (name, sub)) in enumerate(zip(BOXES, OPTS)):
        on = i == sel
        d.rounded_rectangle(box, radius=56, fill=(34, 28, 18) if on else (16, 14, 11),
                            outline=GOLD if on else (60, 52, 38), width=5 if on else 2)
        d.text((box[0] + 80, box[1] + 42), name, font=f_opt, fill=CREAM if on else MUTED)
        d.text((box[0] + 80, box[1] + 130), sub, font=f_sub, fill=GOLD if on else MUTED)
        if on:
            d.ellipse((box[2] - 120, box[1] + 90, box[2] - 80, box[1] + 130), fill=GOLD)
    hint = 'Volume keys to choose  ·  Power to start  ·  or tap'
    ctext(d, 1560, hint, f_hint, MUTED)
    if count:
        ctext(d, 1640, f'Starting {OPTS[sel][0]} in {count}…', f_hint, GOLD)
    return im

def save(im, name):
    raw = im.convert('RGBA').tobytes('raw', 'BGRA')
    with gzip.open(os.path.join(OUT, name + '.bgra.gz'), 'wb', 9) as f:
        f.write(raw)
    im.resize((270, 562)).save(os.path.join(OUT, name + '.preview.png'))

for sel in (0, 1):
    save(frame(sel, None), f'sel{sel}')
    for t in range(1, 9):          # 8 s countdown (3 s was too short to react)
        save(frame(sel, t), f'sel{sel}_t{t}')
print('rendered to', OUT)
