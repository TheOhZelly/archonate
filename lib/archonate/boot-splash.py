"""Boot images: the ARCHONATE block logo, centred on the built-in style's
background. Used for the ISO's boot menus and the installed system's Limine
wallpaper.

    python3 -I boot-splash.py [--size WxH] [--y FRACTION] <logo.txt> <out.png>...

Each image keeps its existing size unless --size says otherwise (640x480 for a
new file). --y puts the logo's bottom edge at that fraction of the height
(default 0.30); --logo-height sizes the logo by height instead of width."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

BG, FG, DIM = "#141618", "#8fa4b2", "#4a5157"
args = sys.argv[1:]
size, ypos, lh = None, 0.30, None
while args and args[0].startswith("--"):
    opt = args.pop(0)
    if opt == "--size":
        size = tuple(int(v) for v in args.pop(0).split("x"))
    elif opt == "--y":
        ypos = float(args.pop(0))
    elif opt == "--logo-height":  # the logo's height as a fraction of the image's
        lh = float(args.pop(0))
rows = Path(args[0]).read_text().rstrip("\n").split("\n")
cols = max(map(len, rows))
for out in map(Path, args[1:]):
    try:
        W, H = size or Image.open(out).size
    except OSError:
        W, H = 640, 480
    s = max(1, int(W * 0.62 / cols))  # logo ~62% of the width, whole pixels
    if lh:  # or as tall as asked (each text row is two pixels of s)
        s = max(1, int(H * lh / (len(rows) * 2)))
    ox, oy = (W - cols * s) // 2, int(H * ypos) - len(rows) * s
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    for y, line in enumerate(rows):
        for x, ch in enumerate(line):
            X, Y = ox + x * s, oy + y * 2 * s
            if ch == "█":
                d.rectangle([X, Y, X + s - 1, Y + 2 * s - 1], fill=FG)
            elif ch == "▀":
                d.rectangle([X, Y, X + s - 1, Y + s - 1], fill=FG)
            elif ch == "▄":
                d.rectangle([X, Y + s, X + s - 1, Y + 2 * s - 1], fill=FG)
    # a thin rule under it, like the poster clock's
    ry = oy + len(rows) * 2 * s + 3 * s
    for x in range(ox, ox + cols * s, max(3, s * 2)):
        d.rectangle([x, ry, x + max(1, s // 2), ry], fill=DIM)
    im.save(out)
    print(out, f"{W}x{H}")
