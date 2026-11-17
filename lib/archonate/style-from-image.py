"""Make an Archonate style from any image.

    python3 -I style-from-image.py <image> [name]

Writes ~/.local/share/archonate/styles/<name>/ (style.json + backgrounds/
with the image and an ARCHONATE logo wallpaper in the new colours) and prints
the style's name. Always dark: the background takes the image's dominant
colour, pushed deep; the accent is its most striking colour, kept readable.
"""
import colorsys
import json
import re
import shutil
import sys
from pathlib import Path

from PIL import Image

HOME = Path.home()
import os
DEST = Path(os.environ.get("ARCHONATE_STYLES_DIR", HOME / ".local/share/archonate/styles"))
LOGO = HOME / ".config/hypr/lib/archonate/logo.txt"

src = Path(sys.argv[1]).expanduser().resolve()
if not src.is_file():
    raise SystemExit(f"no such image: {src}")
slug = re.sub(r"[^a-z0-9]+", "-", (sys.argv[2] if len(sys.argv) > 2 else src.stem).lower()).strip("-")[:32] or "wallpaper"
name = slug if len(sys.argv) > 2 else f"wp-{slug}"
title = " ".join(w.capitalize() for w in slug.split("-"))


# ---- colour helpers --------------------------------------------------------
def to_hex(rgb):
    return "".join(f"{round(max(0, min(1, c)) * 255):02x}" for c in rgb)


def from_hex(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hls(h, l, s):
    return to_hex(colorsys.hls_to_rgb(h % 1, max(0, min(1, l)), max(0, min(1, s))))


def lum(hexc):
    def ch(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = from_hex(hexc)
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hue_dist(a, b):
    d = abs(a - b) % 1
    return min(d, 1 - d)


def readable(h, l, s, bg, need=4.5):
    """The colour at hue h, lightened until it reads on bg."""
    c = hls(h, l, s)
    while contrast(c, bg) < need and l < 0.92:
        l += 0.03
        c = hls(h, l, s)
    return c


def mix(a, b, t):
    ca, cb = from_hex(a), from_hex(b)
    return to_hex(tuple(x + (y - x) * t for x, y in zip(ca, cb)))


# ---- read the image --------------------------------------------------------
img = Image.open(src)
img.seek(0)  # first frame of a gif
img = img.convert("RGB")
img.thumbnail((320, 320))
q = img.quantize(colors=24, method=Image.Quantize.MEDIANCUT)
pal = q.getpalette()
counts = sorted(q.getcolors(), reverse=True)  # (count, index)
total = sum(c for c, _ in counts)
swatches = []
for c, i in counts:
    r, g, b = (x / 255 for x in pal[i * 3:i * 3 + 3])
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    swatches.append({"w": c / total, "h": h, "l": l, "s": s})

# Mood: how colourful the image is overall
mood = sum(x["s"] * x["w"] for x in swatches)

# Background: the most common colour (darker ones favoured), pushed deep
bgsrc = max(swatches, key=lambda x: x["w"] * (1.4 - x["l"]))
bg_s = min(0.35, bgsrc["s"] * 0.55)
bg = hls(bgsrc["h"], 0.09, bg_s)


# Accent: colourful, not muddy, not blown out, and reasonably present
def punch(x):
    return x["w"] ** 0.5 * x["s"] ** 1.3 * (1 - abs(x["l"] - 0.55) * 1.4)


ranked = sorted(swatches, key=punch, reverse=True)
acc = ranked[0]
# A black-and-white image (or nearly) gets a monochrome style
mono = mood < 0.07 or acc["s"] < 0.12
if mono:
    bg = hls(0, 0.07, 0)
    bg_s = 0.0
    bgsrc = dict(bgsrc, s=0.0)
    accent = hls(0, 0.86, 0)
    secondary = hls(0, 0.66, 0)
    tertiary = hls(0, 0.52, 0)
else:
    acc_s = max(0.45, min(0.85, acc["s"] * 1.15))
    accent = readable(acc["h"], max(0.55, min(0.72, acc["l"])), acc_s, bg, 5.0)
    # Secondary / tertiary: the most different hues the image actually has
    others = [x for x in ranked[1:] if x["s"] > 0.15 and hue_dist(x["h"], acc["h"]) > 0.08]
    sec_h = others[0]["h"] if others else (acc["h"] + 0.42) % 1
    ter = next((x for x in others[1:] if hue_dist(x["h"], sec_h) > 0.08 and hue_dist(x["h"], acc["h"]) > 0.08), None)
    ter_h = ter["h"] if ter else (acc["h"] - 0.17) % 1
    side_s = max(0.4, min(0.75, mood * 1.6 + 0.2))
    secondary = readable(sec_h, 0.66, side_s, bg)
    tertiary = readable(ter_h, 0.66, side_s, bg)

# Text: near white, tinted toward the background's hue
text = hls(bgsrc["h"], 0.88, min(0.18, bg_s + 0.05))
text_dim = readable(bgsrc["h"], 0.6, min(0.16, bg_s + 0.04), bg, 4.0)
surface = hls(bgsrc["h"], 0.135, bg_s)
surface_hi = hls(bgsrc["h"], 0.2, bg_s)
muted = hls(bgsrc["h"], 0.34, min(0.2, bg_s + 0.05))

# Terminal colours: the usual hues, in the image's mood, with the accent
# taking the slot nearest its hue
ansi_s = 0.3 if mono else max(0.4, min(0.7, mood * 1.4 + 0.25))
hues = {"red": 0.0, "green": 0.33, "yellow": 0.13, "blue": 0.6, "magenta": 0.83, "cyan": 0.5}
normal = {k: readable(h, 0.62, ansi_s, bg, 4.0) for k, h in hues.items()}
bright = {k: readable(h, 0.72, ansi_s, bg, 5.0) for k, h in hues.items()}
nearest = min(hues, key=lambda k: hue_dist(hues[k], acc["h"]))
if not mono and hue_dist(hues[nearest], acc["h"]) < 0.1:
    normal[nearest] = accent
order = ["red", "green", "yellow", "blue", "magenta", "cyan"]
ansi = [bg] + [normal[k] for k in order] + [text] + [muted] + [bright[k] for k in order] + [hls(bgsrc["h"], 0.95, 0.1)]

palette = {
    "bg": bg, "surface": surface, "surface_hi": surface_hi, "text": text, "text_dim": text_dim,
    "accent": accent, "secondary": secondary, "tertiary": tertiary,
    "error": normal["red"], "muted": muted, "selection": mix(bg, accent, 0.28),
    "dark_bg": hls(bgsrc["h"], 0.05, bg_s),
}

# Folder colour, like the omarchy import
FOLDERS = [(10, "red"), (25, "deeporange"), (40, "orange"), (55, "yellow"), (75, "palebrown"),
           (150, "green"), (175, "teal"), (195, "cyan"), (225, "blue"), (255, "indigo"),
           (285, "violet"), (320, "magenta"), (345, "pink"), (361, "red")]
hh, _, ss = colorsys.rgb_to_hls(*from_hex(accent))
folders = "grey" if ss < 0.18 else next(n for lim, n in FOLDERS if hh * 360 < lim)

# ---- write the style ---------------------------------------------------------
out = DEST / name
base_name, base_title = name, title
n = 2
while out.exists():
    try:
        same = json.loads((out / "style.json").read_text()).get("image") == str(src)
    except (OSError, json.JSONDecodeError):
        same = False
    if same:  # made from this image before: refresh it
        shutil.rmtree(out)
        break
    name, title = f"{base_name}-{n}", f"{base_title} {n}"
    out, n = DEST / name, n + 1
(out / "backgrounds").mkdir(parents=True)
shutil.copy2(src, out / "backgrounds" / ("0-" + re.sub(r"[^A-Za-z0-9._-]+", "-", src.name)))

# The ARCHONATE logo wallpaper in the new colours
from PIL import ImageDraw  # noqa: E402

rows = LOGO.read_text().rstrip("\n").split("\n")
cols = max(map(len, rows))
W, H, s = 3840, 2160, 14
ox, oy = (W - cols * s) // 2, (H - 8 * 2 * s) // 2
im = Image.new("RGB", (W, H), "#" + bg)
d = ImageDraw.Draw(im)
for y, line in enumerate(rows):
    for x, ch in enumerate(line):
        X, Y = ox + x * s, oy + y * 2 * s
        if ch == "█":
            d.rectangle([X, Y, X + s - 1, Y + 2 * s - 1], fill="#" + accent)
        elif ch == "▀":
            d.rectangle([X, Y, X + s - 1, Y + s - 1], fill="#" + accent)
        elif ch == "▄":
            d.rectangle([X, Y + s, X + s - 1, Y + 2 * s - 1], fill="#" + accent)
im.save(out / "backgrounds" / "zz-archonate.png", optimize=True)

(out / "style.json").write_text(json.dumps({
    "name": name, "title": title, "palette": palette, "ansi": ansi,
    "folders": folders, "source": "wallpaper", "image": str(src),
}, indent=4) + "\n")
print(name)
