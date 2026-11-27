"""Build Archonate's skill for AI coding agents.

    python3 -I build-skill.py <out dir>

Writes <out dir>/archonate/SKILL.md from SKILL.md.in: the hand-written guide,
plus the command list (from each command's own `# archonate:summary=` header,
like `archonate help`) and the settings keys, so it never goes stale.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIB = HERE.parent  # lib/archonate
HYPR = LIB.parent.parent  # ~/.config/hypr
CMD = LIB / "cmd"

# What `archonate settings set` takes. Per rice unless marked global.
SETTINGS = [
    ("barClock24", "true|false", "archonate bar: 24-hour time"),
    ("barSeconds", "true|false", "archonate bar: seconds on the clock"),
    ("barDate", "true|false", "archonate bar: weekday and day beside the time"),
    ("barWsNumbers", "true|false", "archonate bar: numbers on every workspace instead of dots"),
    ("barStats", "true|false", "archonate bar: CPU and memory"),
    ("barMedia", "true|false", "archonate bar: now playing"),
    ("barTray", "true|false", "archonate bar: tray icons"),
    ("barVolume", "true|false", "archonate bar: volume percentage"),
    ("barWave", "true|false", "archonate bar: the music line across the top"),
    ("notifSound", '"rice:notify"|path|""', "sound for new notifications (\"\" = silent)"),
    ("wallpaperMinutes", "number", "rotate wallpapers every N minutes (0 = only on demand)"),
    ("idleMinutes", "number", "--global: lock after N idle minutes"),
    ("screenOffMinutes", "number", "--global: screen off after N idle minutes"),
    ("screensaverMinutes", "number", "--global: screensaver after N idle minutes"),
    ("uiSounds", "true|false", "--global: rice sounds (hello, lock, unlock)"),
]


def meta(f, key):
    m = re.search(rf"^# archonate:{key}=(.*)$", f.read_text(errors="replace"), re.M)
    return m.group(1).strip() if m else ""


def commands():
    lines = []
    for f in sorted(CMD.iterdir()):
        if not f.is_file() or meta(f, "hidden") == "true":
            continue
        name = "archonate " + f.name.replace("-", " ")
        args = meta(f, "args")
        lines.append((f"{name} {args}".strip(), meta(f, "summary")))
    width = min(48, max(len(a) for a, _ in lines))
    return "\n".join(f"{a:<{width}}  {s}" if len(a) <= width else f"{a}\n{'':<{width}}  {s}" for a, s in lines)


def version():
    try:
        return subprocess.run(["git", "-C", str(HYPR), "describe", "--tags", "--always"],
                              capture_output=True, text=True).stdout.strip() or "(unknown)"
    except OSError:
        return "(unknown)"


def main():
    out = Path(sys.argv[1]).expanduser() / "archonate"
    text = (HERE / "SKILL.md.in").read_text()
    table = "| key | value | what |\n| --- | --- | --- |\n" + "\n".join(
        f"| `{k}` | `{v}` | {w} |" for k, v, w in SETTINGS)
    text = text.replace("{{VERSION}}", version()).replace("{{SETTINGS}}", table).replace("{{COMMANDS}}", commands())
    out.mkdir(parents=True, exist_ok=True)
    tmp = out / "SKILL.md.tmp"
    tmp.write_text(text)
    tmp.replace(out / "SKILL.md")
    print(out / "SKILL.md")


main()
