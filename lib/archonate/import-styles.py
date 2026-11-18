"""Turn downloaded themes into Archonate styles (worn by the rices with a look.json).

    python3 -I import-styles.py <theme repo checkout> [--force] [--skip-logo=<name>]

Each dark theme becomes ~/.local/share/archonate/styles/<name>/:
    style.json      palette + ANSI in the shape desktop.json uses
    backgrounds/    its wallpapers (other projects' logo ones swapped for ours), and
                    backgrounds/intros/ the animated clips some of them open with
Light themes are skipped. Runs with -I: the checkout is downloaded data.
"""
import colorsys
import json
import shutil
import sys
import tomllib
from pathlib import Path

SRC = Path(sys.argv[1]) / "themes"
FORCE = "--force" in sys.argv
# wallpapers carrying the source project's own logo (named after it) are left out
SKIP_LOGO = next((a.split("=", 1)[1].lower() for a in sys.argv if a.startswith("--skip-logo=")), "")
HOME = Path.home()
DEST = HOME / ".local/share/archonate/styles"
LOGO = HOME / ".config/hypr/lib/archonate/logo.txt"
IMG = {".png", ".jpg", ".jpeg", ".webp", ".gif"}

# Papirus folder colours, by hue (degrees) for anything saturated enough
FOLDERS = [(10, "red"), (25, "deeporange"), (40, "orange"), (55, "yellow"), (75, "palebrown"),
           (150, "green"), (175, "teal"), (195, "cyan"), (225, "blue"), (255, "indigo"),
           (285, "violet"), (320, "magenta"), (345, "pink"), (361, "red")]


def h(x):
    return x.lstrip("#").lower()


def mix(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def hue_dist(a, b):
    ha = colorsys.rgb_to_hsv(*[int(a[i:i + 2], 16) / 255 for i in (0, 2, 4)])[0]
    hb = colorsys.rgb_to_hsv(*[int(b[i:i + 2], 16) / 255 for i in (0, 2, 4)])[0]
    d = abs(ha - hb)
    return min(d, 1 - d)


def folder(accent):
    hh, s, v = colorsys.rgb_to_hsv(*[int(accent[i:i + 2], 16) / 255 for i in (0, 2, 4)])
    if s < 0.18:
        return "grey" if v < 0.75 else "white"
    deg = hh * 360
    return next(n for limit, n in FOLDERS if deg < limit)


def convert(c):
    g = lambda k, d=None: h(c[k]) if k in c else d
    bg, fg, accent = g("background"), g("foreground"), g("accent")
    # secondary/tertiary: the most different colours from the accent, so the
    # screensaver gradient and highlights have somewhere to go
    candidates = [g(k) for k in ("blue", "magenta", "cyan", "green", "yellow", "orange", "red") if g(k)]
    ranked = sorted(candidates, key=lambda x: -hue_dist(x, accent))
    secondary = ranked[0] if ranked else accent
    tertiary = next((x for x in ranked[1:] if hue_dist(x, secondary) > 0.12), secondary)
    palette = {
        "bg": bg,
        "surface": g("lighter_background", mix(bg, fg, 0.06)),
        "surface_hi": mix(g("lighter_background", bg), fg, 0.12),
        "text": fg,
        "text_dim": g("dark_foreground", mix(fg, bg, 0.45)),
        "accent": accent,
        "secondary": secondary,
        "tertiary": tertiary,
        "error": g("red", "ff5555"),
        "muted": g("muted", mix(fg, bg, 0.6)),
        "selection": g("selection", mix(bg, accent, 0.3)),
        "dark_bg": g("darker_background", mix(bg, "000000", 0.3)),
    }
    ansi = [bg, g("red"), g("green"), g("yellow"), g("blue"), g("magenta"), g("cyan"), fg,
            g("muted"), g("bright_red"), g("bright_green"), g("bright_yellow"),
            g("bright_blue"), g("bright_magenta"), g("bright_cyan"), g("bright_foreground")]
    return palette, ansi


def logo_wallpaper(out, bg, fg):
    from PIL import Image, ImageDraw
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
                d.rectangle([X, Y, X + s - 1, Y + 2 * s - 1], fill="#" + fg)
            elif ch == "▀":
                d.rectangle([X, Y, X + s - 1, Y + s - 1], fill="#" + fg)
            elif ch == "▄":
                d.rectangle([X, Y + s, X + s - 1, Y + 2 * s - 1], fill="#" + fg)
    im.save(out, optimize=True)


done, skipped = [], []
for t in sorted(p for p in SRC.iterdir() if p.is_dir()):
    ct = t / "colors.toml"
    if not ct.is_file():
        skipped.append(f"{t.name} (no colors.toml)")
        continue
    c = tomllib.loads(ct.read_text())
    if c.get("mode", "dark") != "dark":
        skipped.append(f"{t.name} (light)")
        continue
    out = DEST / t.name
    if out.exists() and not FORCE:
        skipped.append(f"{t.name} (already imported)")
        continue
    if out.exists():
        shutil.rmtree(out)
    (out / "backgrounds").mkdir(parents=True)
    palette, ansi = convert(c)
    title = " ".join(w.capitalize() for w in t.name.split("-"))
    for f in sorted((t / "backgrounds").iterdir()):
        if f.is_file() and f.suffix.lower() in IMG and not (SKIP_LOGO and SKIP_LOGO in f.name.lower()) and not f.is_symlink():
            shutil.copy2(f, out / "backgrounds" / f.name)
    # Animated intros: backgrounds/intros/<stem>.mp4 plays once, then the still
    intros = t / "backgrounds" / "intros"
    if intros.is_dir():
        kept = {p.stem for p in (out / "backgrounds").iterdir()}
        for clip in sorted(intros.glob("*.mp4")):
            if clip.stem in kept and not clip.is_symlink():
                (out / "backgrounds" / "intros").mkdir(exist_ok=True)
                shutil.copy2(clip, out / "backgrounds" / "intros" / clip.name)
    logo_wallpaper(out / "backgrounds" / "zz-archonate.png", palette["bg"], palette["accent"])
    (out / "style.json").write_text(json.dumps({
        "name": t.name, "title": title, "palette": palette, "ansi": ansi,
        "folders": folder(palette["accent"]), "source": "imported",
    }, indent=4) + "\n")
    done.append(t.name)

print(f"imported {len(done)}: {' '.join(done)}")
if skipped:
    print(f"skipped: {', '.join(skipped)}")
