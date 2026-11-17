"""fastfetch, then a shine across its logo.

Runs fastfetch as usual, then sweeps a diagonal band of light across the
logo by redrawing only the logo's own characters in place (the info beside
it is never touched), and leaves the logo exactly as fastfetch drew it.
Falls back to plain fastfetch when it can't animate safely: not a terminal,
output taller than the window (it scrolled), or ARCHONATE_NO_SHINE set.
Ctrl+C skips to the end.

  fetch-shine.py              run fastfetch, then shine (fastfetch's "shell"
                              line then names this script, not your shell)
  fetch-shine.py --after N    only shine: the caller just printed fastfetch's
                              N lines (zsh does this: archonate_fetch in lib/fetch.zsh)
"""
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

CONFIG = Path.home() / ".config/fastfetch/config.jsonc"
FRAMES, FRAME_S = 34, 0.028  # about a second
BAND = 4.5                    # half-width of the light band, in columns
SLANT = 0.9                   # how much each row shifts the band (diagonal)
GLOW = 0.9                    # how close to white the band gets


def plain():
    os.execvp("fastfetch", ["fastfetch", *sys.argv[1:]])


after = None
if len(sys.argv) == 3 and sys.argv[1] == "--after":
    after = int(sys.argv[2])
elif os.environ.get("ARCHONATE_NO_SHINE") or not sys.stdout.isatty() or len(sys.argv) > 1:
    plain()
if after is not None and (os.environ.get("ARCHONATE_NO_SHINE") or not sys.stdout.isatty()):
    sys.exit(0)

try:
    cfg = json.loads(re.sub(r"^\s*//.*$", "", CONFIG.read_text(), flags=re.M))
    logo = cfg["logo"]
    src = Path(logo["source"]).expanduser()
    colours = {k: tuple(int(x) for x in v.split(";")[2:5]) for k, v in logo.get("color", {}).items()}
    pad = logo.get("padding", {})
    top, left = int(pad.get("top", 0)), int(pad.get("left", 0))
    raw = src.read_text().rstrip("\n").split("\n")
except Exception:
    if after is not None:
        sys.exit(0)
    plain()

# The logo as cells: (column, char, colour) per row, following $N markers
rows, cur = [], next(iter(colours.values()), (255, 255, 255))
for line in raw:
    cells, x, i = [], 0, 0
    while i < len(line):
        m = re.match(r"\$(\d)", line[i:])
        if m:
            cur = colours.get(m.group(1), cur)
            i += 2
            continue
        ch = line[i]
        if ch != " ":
            cells.append((x, ch, cur))
        x += 1
        i += 1
    rows.append(cells)

if after is None:
    out = subprocess.run(["fastfetch", "--pipe", "false"], capture_output=True, text=True).stdout
    sys.stdout.write(out)
    sys.stdout.flush()
    lines = out.count("\n")
else:
    lines = after
try:
    height = os.get_terminal_size().lines
except OSError:
    height = 0
if not rows or lines >= height:
    sys.exit(0)  # it scrolled: the logo isn't where we'd draw


def frame(p):
    """One frame with the band centred at column p (None: original colours)."""
    buf = ["\x1b7"]  # save cursor (end of output)
    for r, cells in enumerate(rows):
        if not cells:
            continue
        buf.append(f"\x1b[{lines - (top + r)}F")  # up to that row, column 1
        for x, ch, (cr, cg, cb) in cells:
            t = 0.0
            if p is not None:
                d = abs(x + r * SLANT - p)
                t = max(0.0, 1 - d / BAND) ** 1.6 * GLOW
            c = (round(cr + (255 - cr) * t), round(cg + (255 - cg) * t), round(cb + (255 - cb) * t))
            buf.append(f"\x1b[{left + x + 1}G\x1b[38;2;{c[0]};{c[1]};{c[2]}m{ch}")
        buf.append("\x1b8\x1b7")  # back to the end before the next row
    buf.append("\x1b[0m\x1b8")
    return "".join(buf)


width = max((x for cells in rows for x, _, _ in cells), default=0) + 1
start, end = -BAND * 2, width + len(rows) * SLANT + BAND * 2
sys.stdout.write("\x1b[?25l")  # hide the cursor while it plays
try:
    for i in range(FRAMES + 1):
        sys.stdout.write(frame(start + (end - start) * i / FRAMES))
        sys.stdout.flush()
        time.sleep(FRAME_S)
except KeyboardInterrupt:
    pass
finally:
    sys.stdout.write(frame(None) + "\x1b[?25h")
    sys.stdout.flush()
