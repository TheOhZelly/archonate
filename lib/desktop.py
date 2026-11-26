#!/usr/bin/env python3
"""Swap whole desktops in and out. Run by hypr-rice / hypr-mode (lib/switch.sh).

  desktop.py swap <from> <to>   stop <from>'s shell, start <to>'s, swap GTK/cursor/kitty
  desktop.py mode <mode>        tell a standalone shell the mode (live wallpaper, bar auto-hide)

Every rice is an Archonate rice: its own Quickshell desktop, colours from its
desktop.json, app themes from lib/templates.
"""
import json
import os
import shutil
import signal
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
HYPR = HOME / ".config/hypr"
STATE = HOME / ".local/state/hypr-rice"
KITTY_DIR = HOME / ".config/kitty"

DISCORD_CLIENTS = ["Equicord", "Vencord", "BetterDiscord", "equibop", "vesktop", "legcord"]
TEMPLATES = HYPR / "lib/templates"


# ---- templates (lib/templates) ----------------------------------------------

def gen_replace(colours, template, hash=False):
    """{{ $name }} -> colour ('#rrggbb' with hash)."""
    t = Path(template).read_text()
    for name, colour in colours.items():
        t = t.replace(f"{{{{ ${name} }}}}", f"#{colour}" if hash else colour)
    return t


def gen_replace_dynamic(colours, template, mode):
    """{{ name.hex }} -> rrggbb, {{ mode }} -> mode (Zed's template)."""
    import re
    t = Path(template).read_text()
    t = re.sub(r"\{\{\s*([A-Za-z0-9_]+)\.hex\s*\}\}", lambda m: colours.get(m.group(1), m.group(0))[:6], t)
    return re.sub(r"\{\{\s*mode\s*\}\}", mode, t)


def gen_scss(colours):
    return "".join(f"${name}: #{colour};\n" for name, colour in colours.items())


def atomic_write(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".archonate-tmp")
    tmp.write_text(text)
    tmp.replace(path)


def run(*cmd):
    return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def detach(*cmd):
    subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def dconf(key, value=None):
    path = f"/org/gnome/desktop/interface/{key}"
    if value is None:
        return subprocess.run(["dconf", "read", path], capture_output=True, text=True).stdout.strip()
    run("dconf", "write", path, value)


def shell_dir(rice):
    return HYPR / "rices" / rice / "shell"


def is_standalone(rice):
    return (shell_dir(rice) / "shell.qml").is_file()


def load_desktop(rice):
    f = HYPR / "rices" / rice / "desktop.json"
    return json.loads(f.read_text()) if f.is_file() else {}


# ---- shells ----------------------------------------------------------------

def stop_shells():
    # All at once: one at a time cost most of a second
    procs = []
    for d in (HYPR / "rices").iterdir():
        if is_standalone(d.name):
            procs.append(subprocess.Popen(["qs", "-p", str(shell_dir(d.name)), "kill"],
                                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    for p in procs:
        p.wait()


def start_shell(rice):
    if is_standalone(rice):
        detach("qs", "-p", str(shell_dir(rice)), "-d")


# ---- standalone rice look --------------------------------------------------

def set_ini(key, value):
    for v in ("gtk-3.0", "gtk-4.0"):
        ini = HOME / ".config" / v / "settings.ini"
        if not ini.is_file():
            continue
        lines = ini.read_text().splitlines()
        lines = [f"{key}={value}" if l.startswith(key + "=") else l for l in lines]
        ini.write_text("\n".join(lines) + "\n")


ICON_THEME = HOME / ".local/share/icons/Papirus-Rice"


def build_folder_icons(colour):
    """User-level 'Papirus-Rice' icon theme: Papirus-Dark with folders in `colour`
    (what papirus-folders does, without touching /usr). Rebuilt on every switch."""
    base = Path("/usr/share/icons/Papirus-Dark")
    if ICON_THEME.exists():
        shutil.rmtree(ICON_THEME)
    dirs = []
    for places in sorted(base.glob("*/places")):
        src = places.resolve()
        out = ICON_THEME / places.parent.name / "places"
        made = False
        for f in src.iterdir():
            if not f.is_symlink():
                continue
            target = os.readlink(f)
            if "-blue" not in target:
                continue
            recolour = src / target.replace("-blue", f"-{colour}")
            if recolour.exists():
                out.mkdir(parents=True, exist_ok=True)
                (out / f.name).symlink_to(recolour)
                made = True
        if made:
            dirs.append(places.parent.name)
    entries = []
    for d in dirs:
        size, _, scale = d.partition("@")
        n = int(size.split("x")[0])
        entry = f"[{d}/places]\nContext=Places\nSize={n}\nType=Fixed"
        if scale:
            entry += f"\nScale={scale.rstrip('x')}"
        entries.append(entry)
    (ICON_THEME / "index.theme").write_text(
        "[Icon Theme]\nName=Papirus-Rice\nComment=Papirus-Dark with folders in the rice's colour (hypr-rice)\n"
        "Inherits=Papirus-Dark,breeze-dark,hicolor\n"
        f"Directories={','.join(d + '/places' for d in dirs)}\n\n" + "\n\n".join(entries) + "\n")


def apply_gtk(desk):
    p = desk["palette"]
    dconf("gtk-theme", "'adw-gtk3-dark'")
    dconf("color-scheme", "'prefer-dark'")
    set_ini("gtk-theme-name", "adw-gtk3-dark")
    icons = desk.get("icons", "Papirus-Dark")
    if desk.get("folders"):
        build_folder_icons(desk["folders"])
    dconf("icon-theme", f"'{icons}'")
    set_ini("gtk-icon-theme-name", icons)

    c = {
        "accent_color": p["accent"], "accent_bg_color": p["accent"], "accent_fg_color": p["bg"],
        "window_bg_color": p["bg"], "window_fg_color": p["text"],
        "view_bg_color": p["surface"], "view_fg_color": p["text"],
        "headerbar_bg_color": p["surface"], "headerbar_fg_color": p["text"],
        "headerbar_backdrop_color": p["bg"],
        "sidebar_bg_color": p["surface"], "sidebar_fg_color": p["text"],
        "card_bg_color": p["surface"], "card_fg_color": p["text"],
        "popover_bg_color": p["surface"], "popover_fg_color": p["text"],
        "dialog_bg_color": p["surface"], "dialog_fg_color": p["text"],
        "borders": p["surface_hi"],
    }
    css = "/* Generated by Archonate for this rice. */\n"
    css += '@import "thunar.css";\n'
    css += "".join(f"@define-color {k} #{v};\n" for k, v in c.items())
    thunar = thunar_css(desk)
    for v in ("gtk-3.0", "gtk-4.0"):
        d = HOME / ".config" / v
        d.mkdir(parents=True, exist_ok=True)
        (d / "gtk.css").write_text(css)
        (d / "thunar.css").write_text(thunar)


def thunar_css(desk):
    """A Thunar layout (sidebar, path bar, tabs) in this rice's colours, corners
    and font. Thunar loads it when it next starts."""
    nt = desk.get("newtab", {})
    r = nt.get("radius", 10)
    css = gen_replace(colour_map(desk), TEMPLATES / "thunar.css", hash=True)
    css = css.replace("border-radius: 15px", f"border-radius: {round(r * 1.1)}px")
    css = css.replace("border-radius: 10px", f"border-radius: {round(r * 0.7)}px")
    css += f"\n/* hypr-rice */\n.thunar * {{ font-family: \"{nt.get('font', 'sans-serif')}\"; }}\n"
    return css


def mix(a, b, t):
    """Blend hex a toward hex b by t (0..1)."""
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def colour_map(desk):
    """The rice palette expanded to the colour names app templates use."""
    base = {}
    for line in (TEMPLATES / "scheme-base.txt").read_text().splitlines():
        if " " in line:
            k, v = line.split(" ", 1)
            base[k] = v.strip()

    p = desk["palette"]
    bg, surf, hi, text, dim = p["bg"], p["surface"], p["surface_hi"], p["text"], p["text_dim"]
    c = dict(base)
    c.update({
        "background": bg, "surface": bg, "surfaceDim": bg,
        "onBackground": text, "onSurface": text, "onSurfaceVariant": dim,
        "surfaceContainerLowest": mix(bg, "000000", 0.5), "surfaceContainerLow": mix(bg, surf, 0.5),
        "surfaceContainer": surf, "surfaceContainerHigh": mix(surf, hi, 0.5),
        "surfaceContainerHighest": hi, "surfaceBright": mix(hi, text, 0.1), "surfaceVariant": hi,
        "outline": mix(bg, text, 0.4), "outlineVariant": mix(bg, text, 0.2),
        "inverseSurface": text, "inverseOnSurface": bg,
        "error": p.get("error", "fa746f"), "onError": bg,
    })
    for role, key in (("primary", "accent"), ("secondary", "secondary"), ("tertiary", "tertiary")):
        col = p.get(key, p["accent"])
        cap = role.capitalize()
        c.update({
            role: col, f"{role}Dim": mix(col, bg, 0.15), f"on{cap}": bg,
            f"{role}Container": mix(col, bg, 0.65), f"on{cap}Container": mix(col, text, 0.5),
            f"{role}Fixed": mix(col, text, 0.25), f"{role}FixedDim": col,
            f"on{cap}Fixed": bg, f"on{cap}FixedVariant": mix(col, bg, 0.6),
        })
    c["inversePrimary"] = mix(p["accent"], bg, 0.5)
    a = desk.get("ansi", [])
    for i, col in enumerate(a):
        c[f"term{i}"] = col
    # The templates also use catppuccin-style names (cava's gradient,
    # nvtop, htop, Zed's syntax); draw them from this rice's terminal colours
    if len(a) >= 16:
        c.update({
            "red": a[1], "maroon": a[9], "flamingo": a[9], "rosewater": mix(text, a[1], 0.3),
            "peach": mix(a[1], a[3], 0.5), "yellow": a[3], "green": a[2], "success": a[2],
            "teal": a[6], "sky": a[14], "sapphire": mix(a[4], a[6], 0.5), "blue": a[4],
            "lavender": a[12], "mauve": a[5], "pink": a[13],
        })
    c.update({
        "text": text, "subtext1": mix(text, dim, 0.5), "subtext0": dim,
        "overlay2": mix(dim, bg, 0.2), "overlay1": mix(dim, bg, 0.4), "overlay0": mix(dim, bg, 0.6),
        "surface2": hi, "surface1": mix(surf, hi, 0.5), "surface0": surf,
        "base": bg, "mantle": mix(bg, "000000", 0.25), "crust": mix(bg, "000000", 0.5),
    })
    return c


def apply_apps(desk, rice=None):
    """btop, Qt (qtengine), nvtop, htop, Zed (theme "Archonate"), cava and
    Discord themes for this rice, from lib/templates. A rice can bring its own
    whole Discord theme (rices/<rice>/discord.theme.scss, replacing the shared
    Midnight one) or additions to it (rices/<rice>/discord.scss)."""
    c = colour_map(desk)
    cfg = HOME / ".config"

    def write(rel, text):
        atomic_write(cfg / rel, text)

    def safely(name, fn):
        try:
            fn()
        except Exception as e:
            print(f"archonate: {name}: {e}", file=sys.stderr)

    safely("btop", lambda: write("btop/themes/archonate.theme", gen_replace(c, TEMPLATES / "btop.theme", hash=True)))
    run("killall", "-USR2", "btop")

    write("qtengine/archonate.colors", gen_replace(c, TEMPLATES / "qtdark.colors", hash=True))
    qcfg = (TEMPLATES / "qtengine.json").read_text().replace("{{ $mode }}", "Dark")
    qcfg = qcfg.replace('"iconTheme": "Papirus-Dark"', f'"iconTheme": "{desk.get("icons", "Papirus-Dark")}"')
    write("qtengine/config.json", qcfg)

    safely("nvtop", lambda: write("nvtop/nvtop.colors", gen_replace(c, TEMPLATES / "nvtop.colors", hash=True)))
    safely("htop", lambda: write("htop/htoprc", gen_replace(c, TEMPLATES / "htop.theme", hash=True)))

    def cava():
        write("cava/config", gen_replace(c, TEMPLATES / "cava.conf", hash=True))
        run("killall", "-USR2", "cava")
    safely("cava", cava)

    def zed():
        p = cfg / "zed/themes/archonate.json"
        if p.is_symlink():  # Zed's watcher doesn't follow symlinks
            p.unlink()
        write("zed/themes/archonate.json", gen_replace_dynamic(c, TEMPLATES / "zed.json", "dark"))
    safely("zed", zed)
    safely("obs", lambda: apply_obs(desk, rice or active_rice()))

    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "_colours.scss").write_text(gen_scss(c))
        rdir = HYPR / "rices" / (rice or active_rice() or "")
        own, extra = rdir / "discord.theme.scss", rdir / "discord.scss"
        # a rice's own whole theme replaces the shared one (falling back to it on a compile error)
        css = ""
        if own.is_file():
            r = subprocess.run(["sass", "-I", tmp, str(own)], capture_output=True, text=True)
            css = r.stdout if r.returncode == 0 else ""
            if r.returncode:
                print(f"archonate: discord ({rdir.name}): {r.stderr.strip()}", file=sys.stderr)
        if not css:
            css = subprocess.run(["sass", "-I", tmp, str(TEMPLATES / "discord.scss")],
                                 capture_output=True, text=True).stdout
            # or just a few additions on top of it
            if css and extra.is_file():
                more = subprocess.run(["sass", "-I", tmp, str(extra)], capture_output=True, text=True)
                if more.returncode == 0:
                    css += "\n" + more.stdout
                else:
                    print(f"archonate: discord ({rdir.name}): {more.stderr.strip()}", file=sys.stderr)
    if css:
        for client in DISCORD_CLIENTS:
            if (cfg / client).is_dir():
                write(f"{client}/themes/archonate.theme.css", css)


CLAUDE_CFG = HOME / ".config/Claude"


def hsl(h):
    """'rrggbb' -> 'H S% L%', the triplet Claude's theme tokens take."""
    import colorsys
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    return f"{round(hh * 360)} {round(ss * 100, 1)}% {round(ll * 100, 1)}%"


def luminance(h):
    def ch(v):
        v = int(v, 16) / 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(h[i:i + 2]) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def claude_css(look, acc, hi, text):
    """The rice's shape, type and borders as CSS for the Claude app: corner
    radius, fonts, border weight and colour, label casing and tracking, the
    composer's focus glow. Colours come from the theme tokens; this is the rest.
    Anchors are the app's own design-system variables and data-cds names (its
    Code UI is local; the Chat pages share the same tokens), so a claude.ai
    redesign degrades to Claude's stock shapes rather than breaking."""
    R = look.get("radius", 12)
    bw = look.get("borderWidth", 1)
    border = "#" + look.get("border", mix(hi, text, 0.2) + "ff")
    font = look.get("font") or "sans-serif"
    tr = look.get("tracking", 0.0)
    caps = look.get("caps", "none")
    sharp = R <= 6
    f = f"'{font}', sans-serif"
    mono = "'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace"
    px = lambda k: f"{round(R * k)}px"
    css = []

    # Corners: every radius token on the rice's scale. Sharp rices square
    # off pills and controls too; round ones keep pills round.
    toks = {"--radius-sm": px(0.4), "--radius-md": px(0.6), "--radius-lg": px(0.8), "--radius-xl": px(1),
            "--radius-2xl": px(1.2), "--radius-3xl": px(1.5), "--radius-card": px(1), "--radius-chip": px(0.6),
            "--cds-radius-composer": px(1.2), "--cds-panel-radius": px(1), "--df-radius-card": px(1),
            "--msg-block-radius": px(0.8), "--cds-message-bubble-radius": px(1.2), "--cds-checkbox-radius": px(0.3),
            "--cds-keycap-radius": px(0.3), "--accordion-radius": px(0.8), "--question-radius": px(1)}
    if sharp:
        toks["--df-radius-pill"] = px(1)
    css.append("*{" + "".join(f"{k}:{v} !important;" for k, v in toks.items()) + "}")
    if sharp:
        css.append(f"[data-cds]:not([data-cds=Avatar]):not([data-cds=Spinner]):not([data-cds=Pulse]){{--cds-radius:{px(1)} !important}}")
        css.append(",".join(f".rounded{s}" for s in ("", "-sm", "-md", "-lg", "-xl", "-2xl", "-3xl", "-card", "-chip", "-composer", "-full"))
                   + f"{{border-radius:{px(1)} !important}}")
        css.append(".rounded-full:has(> img),[data-cds=Avatar] *{border-radius:9999px !important}")
    else:
        css.append(f".rounded-xl,.rounded-2xl,.rounded-card{{border-radius:{px(1)} !important}}"
                   f".rounded-composer,.rounded-3xl{{border-radius:{px(1.2)} !important}}")

    # Type: the rice's font for the interface and for Claude's replies; code stays mono
    fontvars = ("--cds-font-sans", "--font-anthropic-sans", "--font-anthropic-serif", "--cds-font-voice",
                "--font-ui", "--font-sans", "--font-serif", "--font-claude-response")
    css.append("*{" + "".join(f"{k}:{f} !important;" for k in fontvars)
               + f"--cds-font-mono-override:{mono},;--font-anthropic-mono:{mono} !important}}")
    css.append(f"body,button,input,textarea,select,.font-sans,.font-serif,.font-claude-response-body,"
               f".font-claude-response-title,[data-user-message-bubble]{{font-family:{f} !important}}")
    css.append(f"code,pre,kbd,samp,.font-mono,[data-cds=CodeView],[data-ccd-terminal] *{{font-family:{mono} !important}}")

    # Borders: the rice's weight and colour on the framed things
    framed = ("[data-cds=Card]", "[data-cds=Panel]", "[data-cds=Banner]", "[data-cds=AskUserQuestion]",
              "[data-cds=PreviewCard]", "[data-cds=CommentCard]", "[data-cds=Dialog]", "[data-cds=Combobox]",
              "[data-cds=TextInput]", "[data-cds=TextArea]", "[data-cds=DataTable]", "[data-cds=FileDiff]",
              "[data-cds=Accordion]", "[role=menu]", "[role=dialog]", "[role=listbox]")
    css.append(",".join(framed) + f"{{border:{bw}px solid {border} !important;box-shadow:none !important}}")
    comp = "[data-cds=ChatComposer] .rounded-composer,[data-chat-input-container] .rounded-composer"
    css.append(f"{comp}{{border:{bw}px solid {border} !important;box-shadow:none !important;"
               f"transition:border-color .15s,box-shadow .15s}}")
    css.append(f"{comp.replace('.rounded-composer', '.rounded-composer:focus-within')}"
               f"{{border-color:#{acc} !important;box-shadow:0 0 0 {max(1, bw)}px #{acc}40,0 0 18px #{acc}26 !important}}")
    # the field inside the composer is part of its frame, not a second box
    css.append("[data-cds=ChatComposer] [data-cds=TextArea],[data-cds=ChatComposer] [data-cds=TextInput],"
               "[data-cds=ChatComposerEditor],[data-cds=ChatComposerEditor] *{border:0 !important;outline:none !important;box-shadow:none !important}")
    css.append(f"[data-user-message-bubble]{{border:{bw}px solid {border} !important}}")
    css.append(f".dframe-sidebar{{border-right:{bw}px solid {border} !important}}")

    # Labels: the rice's casing and tracking on controls and headers, never on
    # what you or Claude wrote
    # (not plain buttons: some hold names, like the project path or your profile)
    labels = ("[data-cds=Tabs] [role=tab]", "[data-cds=NavigationTabs] a", "[data-cds=Badge]",
              "[data-cds=SegmentedControl]", "[data-cds=AccordionHeader]", "[data-cds-part=page-header-ground] h1",
              "[data-cds-part=page-header-ground] h2", "[data-cds=Toolbar] h1", "[data-cds=Toolbar] h2", "h3")
    transform = {"upper": "uppercase", "lower": "lowercase"}.get(caps)
    rule = ""
    if transform:
        rule += f"text-transform:{transform} !important;"
    if tr or transform == "uppercase":
        rule += f"letter-spacing:{min(max(tr, 0.6 if transform == 'uppercase' else 0), 1.6) / 13:.3f}em !important;"
    if rule:
        css.append(",".join(labels) + "{" + rule + "}")

    css.append(f"::selection{{background:#{acc}55}}")
    css.append(f"*{{scrollbar-color:#{mix(hi, text, 0.15)} transparent;scrollbar-width:thin}}")
    css.append(f"button:focus-visible,a:focus-visible,[role=tab]:focus-visible,[role=menuitem]:focus-visible"
               f"{{outline:{max(1, bw)}px solid #{acc} !important;outline-offset:1px}}")
    return css


def apply_obs(desk, rice):
    """OBS Studio's theme 'Archonate': a variant of its built-in Yami with this
    rice's palette, accent, font, border weight and corners, written to
    ~/.config/obs-studio/themes/Archonate.ovt. Pick it once in OBS (Settings >
    Appearance: theme Yami, style Archonate); later rice or style switches
    rewrite it, and OBS restyles live: Archonate turns on OBS's own
    Appearance > AutoReload, which watches the theme files. Skipped without OBS."""
    cfg = HOME / ".config/obs-studio"
    if not cfg.is_dir():
        return
    p = desk["palette"]
    bg, surf, hi, text, dim, acc = p["bg"], p["surface"], p["surface_hi"], p["text"], p["text_dim"], p["accent"]
    look = rice_look(rice)
    k = 0.0
    while contrast(mix(dim, text, k), surf) < 4.5 and k < 1:  # muted text stays readable
        k += 0.05
    dim = mix(dim, text, min(k, 1.0))
    on_acc = bg if contrast(acc, bg) >= contrast(acc, text) else text
    border = look.get("border", mix(hi, text, 0.2) + "ff")
    rgba = f"rgba({int(border[0:2], 16)}, {int(border[2:4], 16)}, {int(border[4:6], 16)}, {int(border[6:8], 16)})"
    bw = max(1, look.get("borderWidth", 1))
    r = round(min(look.get("radius", 8), 10) * 0.6)
    font = look.get("font") or "sans-serif"
    v = {
        # Yami's grey ramp, lightest (1) to darkest (8), from the rice's surfaces
        "grey1": mix(hi, text, 0.25), "grey2": mix(hi, text, 0.12), "grey3": hi, "grey4": mix(surf, hi, 0.5),
        "grey5": surf, "grey6": mix(bg, surf, 0.5), "grey7": bg, "grey8": mix(bg, "000000", 0.35),
        # its blues are the accent everywhere (selection, links, sliders)
        "blue1": mix(acc, text, 0.4), "blue2": mix(acc, text, 0.2), "blue3": acc, "blue4": mix(acc, bg, 0.25),
        "blue5": mix(acc, bg, 0.45), "blue6": mix(acc, bg, 0.65),
        "white1": text, "white2": mix(text, dim, 0.3), "white3": mix(text, dim, 0.5), "white4": mix(text, dim, 0.75),
        "white5": dim,
    }
    lines = "\n".join(f"    --{n}: #{c};" for n, c in v.items())
    css = f"""/* Archonate: written on every rice/style switch ({rice}); edits are overwritten. */

@OBSThemeMeta {{
    name: 'Archonate';
    id: 'com.archonate.Yami.Archonate';
    extends: 'com.obsproject.Yami';
    author: 'Archonate';
    dark: 'true';
}}

@OBSThemeVars {{
{lines}
    --text_muted: #{dim};
    --border_color: {rgba};
    --input_border: {rgba};
    --input_border_hover: #{mix(acc, text, 0.2)};
    --input_border_width: {bw}px;
    --button_border: {rgba};
    --button_border_hover: #{acc};
    --highlight_color: #{acc};
}}

QWidget {{
    font-family: '{font}', sans-serif;
}}

QPushButton, QLineEdit, QComboBox, QSpinBox, QDoubleSpinBox, QTextEdit, QPlainTextEdit,
QListWidget, QTreeView, QTableView, QMenu, QToolTip {{
    border-radius: {r}px;
}}

QMenu::item:selected, QListWidget::item:selected {{
    color: #{on_acc};
}}
"""
    atomic_write(cfg / "themes" / "Archonate.ovt", css)
    obs_autoreload(cfg / "user.ini")


def obs_autoreload(ini):
    """Set [Appearance] AutoReload=true in OBS's user.ini, so OBS reloads its
    theme when the file changes. Only while OBS is closed: it rewrites user.ini
    from memory on exit, so an edit made while it runs would be lost (the next
    switch with OBS closed sets it, and it takes effect from OBS's next start)."""
    if not ini.is_file() or subprocess.run(["pgrep", "-x", "obs"], capture_output=True).returncode == 0:
        return
    lines = ini.read_text().splitlines()
    sect, at, done = None, None, False
    for i, ln in enumerate(lines):
        t = ln.strip()
        if t.startswith("[") and t.endswith("]"):
            sect = t[1:-1]
            if sect == "Appearance":
                at = i + 1
        elif sect == "Appearance" and t.split("=", 1)[0] == "AutoReload":
            if t == "AutoReload=true":
                return
            lines[i], done = "AutoReload=true", True
    if not done:
        if at is None:
            lines += ["", "[Appearance]"]
            at = len(lines)
        lines.insert(at, "AutoReload=true")
    atomic_write(ini, "\n".join(lines) + "\n")


def apply_claude(rice, desk):
    """The Claude app (claude-desktop-extra) wearing this rice: writes
    ~/.config/Claude/themes.d/archonate.jsonc and makes it the active theme. The
    app watches both files and restyles every open window live; nothing is
    written into the app itself. Skipped when the app was never run here."""
    if not CLAUDE_CFG.is_dir():
        return
    c = colour_map(desk)
    look = rice_look(rice)
    p = desk["palette"]
    bg, surf, hi, text, dim, acc = p["bg"], p["surface"], p["surface_hi"], p["text"], p["text_dim"], p["accent"]
    k = 0.0
    while contrast(mix(dim, text, k), hi) < 4.5 and k < 1:  # muted text stays readable on panels
        k += 0.05
    dim = mix(dim, text, min(k, 1.0))
    sec = p.get("secondary", acc)
    err = p.get("error", c["red"])
    warn, ok = c["yellow"], c["green"]
    on_acc = bg if contrast(acc, bg) >= contrast(acc, text) else text
    t = {
        # surfaces: 000 floats highest (panels, popovers), 400/500 the deepest
        "--bg-000": hsl(hi), "--bg-100": hsl(surf), "--bg-200": hsl(bg),
        "--bg-300": hsl(mix(bg, "000000", 0.2)), "--bg-400": hsl(mix(bg, "000000", 0.2)),
        "--bg-500": hsl(mix(bg, "000000", 0.4)),
        **{f"--text-{n}": hsl(text) for n in ("000", "100", "200", "300")},
        "--text-400": hsl(dim), "--text-500": hsl(dim),
        **{f"--accent-{n}": hsl(acc) for n in ("brand", "000", "100", "200")},
        "--accent-900": hsl(mix(acc, bg, 0.7)),
        **{f"--accent-pro-{n}": hsl(sec) for n in ("000", "100", "200")},
        "--accent-pro-900": hsl(mix(sec, bg, 0.7)),
        **{f"--brand-{n}": hsl(acc) for n in ("000", "100", "200")},
        "--brand-900": "0 0% 0%",
        # borders are drawn at low alpha, so in a dark theme the raw value is light
        **{f"--border-{n}": hsl(mix(dim, text, 0.3)) for n in ("100", "200", "300", "400")},
        **{f"--danger-{n}": hsl(err) for n in ("000", "100", "200")}, "--danger-900": hsl(mix(err, bg, 0.75)),
        **{f"--warning-{n}": hsl(warn) for n in ("000", "100", "200")}, "--warning-900": hsl(mix(warn, bg, 0.75)),
        **{f"--success-{n}": hsl(ok) for n in ("000", "100", "200")}, "--success-900": hsl(mix(ok, bg, 0.75)),
        **{f"--oncolor-{n}": hsl(on_acc) for n in ("100", "200", "300")},
        "--pictogram-100": hsl(text), "--pictogram-200": hsl(text), "--pictogram-300": hsl(dim),
        "--pictogram-400": hsl(hi),
        # the window chrome (title bar, Quick Entry, About) takes hex
        "--claude-accent-clay": f"#{acc}", "--claude-background-color": f"#{bg}",
        "--claude-foreground-color": f"#{text}", "--claude-secondary-color": f"#{dim}",
        "--claude-border": f"#{acc}20", "--claude-border-300": f"#{acc}38", "--claude-border-300-more": f"#{acc}60",
        "--claude-description-text": f"#{dim}", "--claude-text-100": f"#{text}", "--claude-text-200": f"#{text}",
        "--claude-text-400": f"#{dim}", "--claude-text-500": f"#{dim}",
    }
    css = claude_css(look, acc, hi, text)
    font = look.get("font")
    theme = {
        "name": f"Archonate ({rice})",
        # dark in both of the app's modes: the rice decides, not Settings > Appearance
        "light": t, "dark": t,
        "customCss": css,
    }
    if font:
        theme["chatFont"] = f"'{font}', sans-serif"
    atomic_write(CLAUDE_CFG / "themes.d/archonate.jsonc",
                 "// written by archonate on every rice/style switch; edits are overwritten\n"
                 + json.dumps(theme, indent=2) + "\n")
    # Point the app at it, leaving the rest of the file (and its comments) alone
    import re
    cfg = CLAUDE_CFG / "claude-desktop-extra.jsonc"
    src = cfg.read_text() if cfg.is_file() else '{\n  // archonate keeps this on its own theme\n  "activeTheme": "archonate"\n}\n'
    if re.search(r'"activeTheme"\s*:', src):
        new = re.sub(r'("activeTheme"\s*:\s*)"[^"]*"', r'\1"archonate"', src, count=1)
    else:
        new = re.sub(r"\{", '{\n  "activeTheme": "archonate",', src, count=1)
    if new != src or not cfg.is_file():
        atomic_write(cfg, new)


def rgb(h):
    return ";".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


def apply_fastfetch(rice, desk):
    """The fastfetch layout (lib/templates/fastfetch.jsonc) with this rice's logo and colours."""
    ff = desk.get("fastfetch")
    base = TEMPLATES / "fastfetch.jsonc"
    if not ff or not base.is_file():
        return
    p = desk["palette"]
    cfg = json.loads(base.read_text())
    cfg["display"]["color"] = "38;2;" + rgb(p["text_dim"])
    # $1 plain text, $2..$4 the icon colours in the box
    cfg["display"]["constants"] = ["\u001b[38;2;" + rgb(p[k]) + "m" for k in ("text", "accent", "secondary", "tertiary")]
    logo = dict(ff["logo"])
    if logo["type"] == "file":
        logo["source"] = str(HYPR / "rices" / rice / logo["source"])
    logo["color"] = {str(i + 1): "38;2;" + rgb(p[k]) for i, k in enumerate(logo.pop("colors", []))}
    logo["padding"] = {"top": 1, "left": 2, "right": 3}
    cfg["logo"] = logo
    out = HOME / ".config/fastfetch/config.jsonc"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(cfg, indent=4, ensure_ascii=False) + "\n")


PROMPT_FILE = STATE / "p10k.zsh"


def apply_prompt(desk):
    """The zsh prompt's colours for this rice (lib/zsh/prompt-theme.zsh reads
    them); ~/.zshrc re-sources on change. No palette: the theme's defaults."""
    p = desk.get("palette")
    if not p:
        PROMPT_FILE.unlink(missing_ok=True)
        return
    keys = {"frame": "surface_hi", "text": "text", "dim": "text_dim", "accent": "accent",
            "secondary": "secondary", "tertiary": "tertiary", "error": "error"}
    pairs = " ".join(f"{k} '#{p[v]}'" for k, v in keys.items() if p.get(v))
    PROMPT_FILE.parent.mkdir(parents=True, exist_ok=True)
    PROMPT_FILE.write_text("# Generated by hypr-rice for the active rice: the prompt's colours.\n"
                           f"typeset -gA ARCHONATE_PROMPT=({pairs})\n")


BRAVE_POLICY = Path("/etc/brave/policies/managed/hypr-rice.json")
NEWTAB_DIR = HOME / ".local/share/hypr-rice/newtab"

NEWTAB_HTML = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>New Tab</title>
<style>
  :root { --bg:#{bg}; --surface:#{surface}; --text:#{text}; --dim:#{text_dim}; --accent:#{accent};
          --font:"{font}", sans-serif; --weight:{weight}; --radius:{radius}px; }
  html, body { margin:0; height:100%; background:var(--bg); color:var(--text); font-family:var(--font); }
  body { background: linear-gradient(to bottom, color-mix(in srgb, var(--bg) 35%, transparent), color-mix(in srgb, var(--bg) 85%, transparent)){bg_image};
         display:flex; flex-direction:column; align-items:center; justify-content:center; gap:14px; }
  .greet { color:var(--accent); letter-spacing:.3em; font-size:14px; text-transform:uppercase; min-height:1em; }
  .clock { font-size:132px; font-weight:var(--weight); line-height:1; {clock_style} }
  .date { color:var(--dim); font-size:18px; letter-spacing:.08em; {upper} }
  form { margin-top:34px; }
  input { width:min(560px, 80vw); padding:15px 20px; font:inherit; font-size:17px; color:var(--text);
          background:color-mix(in srgb, var(--surface) 82%, transparent); border:1px solid color-mix(in srgb, var(--accent) 45%, transparent);
          border-radius:var(--radius); outline:none; backdrop-filter:blur(16px); }
  input:focus { border-color:var(--accent); }
  input::placeholder { color:var(--dim); {upper} }
</style></head>
<body>
  <div class="greet">{greeting}</div>
  <div class="clock" id="clock"></div>
  <div class="date" id="date"></div>
  <form action="https://search.brave.com/search"><input name="q" placeholder="Search" autofocus autocomplete="off"></form>
<script>
  const pad = n => String(n).padStart(2, "0");
  function tick() {
    const d = new Date();
    document.getElementById("clock").textContent = pad(d.getHours()) + ":" + pad(d.getMinutes());
    document.getElementById("date").textContent = d.toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" });
  }
  tick(); setInterval(tick, 1000);
</script>
</body></html>
"""


def apply_newtab(rice, desk):
    """Local new-tab page in the rice's look; Brave points at it via policy."""
    p, nt = desk["palette"], desk.get("newtab", {})
    NEWTAB_DIR.mkdir(parents=True, exist_ok=True)
    bg_image = ""
    wall = preview(rice)["wallpaper"]
    if wall:
        from PIL import Image
        img = Image.open(wall)
        img.seek(0)
        img = img.convert("RGB")
        img.thumbnail((2560, 2560))
        img.save(NEWTAB_DIR / "bg.jpg", quality=90)
        bg_image = ", url('bg.jpg') center / cover no-repeat"
    clock_style = "font-style:italic; color:#%s; text-shadow:0 0 24px #%s;" % (p["tertiary"], p["accent"]) if nt.get("italic") else ""
    html = NEWTAB_HTML
    for k, v in {
        "bg": p["bg"], "surface": p["surface"], "text": p["text"], "text_dim": p["text_dim"], "accent": p["accent"],
        "font": nt.get("font", "sans-serif"), "weight": str(nt.get("weight", 400)), "radius": str(nt.get("radius", 8)),
        "bg_image": bg_image, "clock_style": clock_style, "greeting": nt.get("greeting", ""),
        "upper": "text-transform:uppercase;" if nt.get("upper") or nt.get("italic") else "",
    }.items():
        html = html.replace("{" + k + "}", v)
    (NEWTAB_DIR / "index.html").write_text(html)
LOGIN_DIR = Path("/var/lib/hypr-rice-login")


def apply_brave(desk):
    """Brave's toolbar colour follows the rice (needs lib/setup-root.sh once)."""
    if not os.access(BRAVE_POLICY, os.W_OK):
        return
    p = desk.get("palette")
    policy = {}
    if p:
        policy = {
            "BrowserThemeColor": "#" + p["surface"],
            "BrowserColorScheme": "dark",
            "NewTabPageLocation": (NEWTAB_DIR / "index.html").as_uri(),
        }
    BRAVE_POLICY.write_text(json.dumps(policy) + "\n")
    # Running Brave picks it up now; otherwise on next launch
    if subprocess.run(["pgrep", "-f", "brave-origin"], capture_output=True).returncode == 0:
        run("brave-origin", "--refresh-platform-policy", "--no-startup-window")


def apply_login(rice):
    """Login screen wallpaper follows the rice (needs lib/setup-root.sh once)."""
    if not os.access(LOGIN_DIR, os.W_OK):
        return
    wall = preview(rice)["wallpaper"]
    if not wall:
        return
    from PIL import Image
    img = Image.open(wall)
    img.seek(0)  # first frame of gifs
    img = img.convert("RGB")
    img.thumbnail((2560, 2560))
    tmp = LOGIN_DIR / "wallpaper.tmp.jpg"
    img.save(tmp, quality=92)
    tmp.chmod(0o644)
    tmp.replace(LOGIN_DIR / "wallpaper.jpg")
    login_theme(rice)


def login_theme(rice):
    """Colours and font for the ARCHONATE login screen (SDDM reads this as
    theme.conf.user via a symlink that lib/setup-login.sh puts in place)."""
    import re
    p = load_desktop(rice).get("palette", {})
    if not p:
        return
    font, radius = "Rubik", 16
    tq = shell_dir(rice) / "Theme.qml"
    if tq.is_file():
        t = tq.read_text()
        m = re.search(r'property string font: "([^"]+)"', t)
        font = m.group(1) if m else font
        m = re.search(r'property int radius: (\d+)', t)
        radius = int(m.group(1)) if m else radius
    conf = "\n".join([
        "[General]", f"rice={rice}", f"background={LOGIN_DIR / 'wallpaper.jpg'}",
        f"bg=#{p.get('bg', '1a1a1a')}", f"surface=#{p.get('surface', '262626')}",
        f"accent=#{p.get('accent', 'ffffff')}", f"text=#{p.get('text', 'ffffff')}",
        f"textDim=#{p.get('text_dim', 'aaaaaa')}", f"error=#{p.get('error', 'ff5555')}",
        f"font={font}", f"radius={radius}", ""])
    tmp = LOGIN_DIR / "theme.conf.tmp"
    tmp.write_text(conf)
    tmp.chmod(0o644)
    tmp.replace(LOGIN_DIR / "theme.conf")


def apply_cursor(desk):
    cur = desk.get("cursor")
    if not cur:
        return
    theme, size = cur["theme"], str(cur.get("size", 24))
    run("hyprctl", "setcursor", theme, size)
    dconf("cursor-theme", f"'{theme}'")
    dconf("cursor-size", size)
    set_ini("gtk-cursor-theme-name", theme)
    set_ini("gtk-cursor-theme-size", size)


def apply_kitty(desk):
    KITTY_DIR.mkdir(parents=True, exist_ok=True)
    conf = KITTY_DIR / "kitty.conf"
    inc = "include rice.conf"
    if not conf.is_file():
        conf.write_text(f"# kitty config. rice.conf is written by hypr-rice.\n{inc}\n")
    elif inc not in conf.read_text():
        conf.write_text(conf.read_text().rstrip("\n") + f"\n\n{inc}\n")

    p, k = desk.get("palette"), desk.get("kitty", {})
    if not p:
        (KITTY_DIR / "rice.conf").write_text("# no palette: kitty untouched\n")
    else:
        lines = [
            "# Generated by hypr-rice, do not edit",
            f"foreground #{p['text']}", f"background #{p['bg']}",
            f"selection_foreground #{p['bg']}", f"selection_background #{p['accent']}",
            f"cursor #{p['accent']}", f"cursor_text_color #{p['bg']}",
            f"url_color #{p['accent']}",
            f"active_border_color #{p['accent']}", f"inactive_border_color #{p['surface_hi']}",
            f"active_tab_foreground #{p['bg']}", f"active_tab_background #{p['accent']}",
            f"inactive_tab_foreground #{p['text_dim']}", f"inactive_tab_background #{p['surface']}",
            f"tab_bar_background #{p['bg']}",
            f"background_opacity {k.get('opacity', 1.0)}",
            f"window_padding_width {k.get('padding', 8)}",
            f"cursor_shape {k.get('cursor_shape', 'block')}",
        ]
        if k.get("font"):
            lines.append(f"font_family {k['font']}")
        if k.get("blur"):
            lines.append(f"background_blur {k['blur']}")
        lines += [f"color{i} #{c}" for i, c in enumerate(desk.get("ansi", []))]
        (KITTY_DIR / "rice.conf").write_text("\n".join(lines) + "\n")

    # kitty reloads its config on SIGUSR1
    pids = subprocess.run(["pgrep", "-x", "kitty"], capture_output=True, text=True).stdout.split()
    for pid in pids:
        try:
            os.kill(int(pid), signal.SIGUSR1)
        except OSError:
            pass


# ---- entry -----------------------------------------------------------------

def swap(old, new):
    """What you see first: GTK, cursor, terminal colours and the new shell.
    Everything else follows in the background (swap_rest), so the switch
    returns as soon as the screen has changed."""
    if is_styled(new) and current_style(new):
        build_style(current_style(new), new)
    stop_shells()

    desk = load_desktop(new)
    apply_gtk(desk)
    apply_cursor(desk)
    apply_kitty(desk)
    start_shell(new)
    detach(sys.executable, str(HYPR / "lib/desktop.py"), "swap-rest", new)


def active_rice():
    link = HYPR / "active-rice.lua"
    return Path(os.readlink(link)).parent.name if link.is_symlink() else "archonate"


def swap_rest(new):
    """The apps nobody is looking at yet: btop/Qt/Discord/Zed/cava, fastfetch,
    the prompt, Spotify, the new-tab page, Brave and the login screen. One
    batch at a time, and a batch whose rice was already replaced stops, so an
    older rice never lands after a newer one."""
    import fcntl
    lock = open(STATE / "swap-rest.lock", "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    desk = load_desktop(new)
    steps = [("apps", lambda: apply_apps(desk, new)), ("claude", lambda: apply_claude(new, desk)),
             ("fastfetch", lambda: apply_fastfetch(new, desk))]
    steps.append(("prompt", lambda: apply_prompt(desk)))
    if not os.environ.get("ARCHONATE_NO_SPOTIFY"):  # set by `archonate theme preview --all`
        steps.append(("spotify", lambda: apply_spotify(new, desk)))
    steps.append(("newtab", lambda: apply_newtab(new, desk)))
    steps += [("brave", lambda: apply_brave(desk)), ("login", lambda: apply_login(new))]
    failed = []
    for name, fn in steps:
        if active_rice() != new:
            return
        try:
            fn()
        except Exception as e:
            print(f"archonate: {name}: {e}", file=sys.stderr)
            failed.append(name)
    if failed and active_rice() == new:
        run("notify-send", "-a", "archonate", "Rice applied, mostly",
            f"Couldn't restyle: {', '.join(failed)}")


def mode(name):
    link = HYPR / "active-rice.lua"
    rice = Path(os.readlink(link)).parent.name if link.is_symlink() else None
    if rice and is_standalone(rice):
        run("qs", "-p", str(shell_dir(rice)), "ipc", "call", "rice", "setMode", name)


def preview(rice):
    """Wallpaper still + key colours for the picker."""
    cache = HOME / ".cache/hypr-rice"
    assets = HYPR / "rices" / rice / "assets"
    exts = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".mp4", ".webm", ".mkv", ".mov"}
    walls = [f for f in sorted(assets.glob("wallpaper.*")) + sorted(assets.glob("wallpapers/*"))
             if f.suffix.lower() in exts]
    try:
        idx = int((STATE / f"wall-{rice}").read_text())
    except (OSError, ValueError):
        idx = 0
    wall = walls[idx % len(walls)] if walls else None
    p = load_desktop(rice).get("palette", {})
    colours = {"bg": p.get("bg", "000000"), "accent": p.get("accent", "ffffff"), "text": p.get("text", "ffffff")}
    if wall and wall.suffix.lower() in {".mp4", ".webm", ".mkv", ".mov"}:
        still = cache / f"still-{rice}.png"
        if not still.is_file() or still.stat().st_mtime < wall.stat().st_mtime:
            cache.mkdir(parents=True, exist_ok=True)
            run("ffmpeg", "-y", "-i", str(wall), "-frames:v", "1", str(still))
        wall = still
    shot = STATE / "previews" / f"{rice}.png"  # archonate theme preview
    swatches = [p[k] for k in ("bg", "surface", "surface_hi", "text_dim", "text", "accent", "secondary", "tertiary") if k in p]
    return {"name": rice, "wallpaper": str(wall.resolve()) if wall and wall.exists() else "",
            "shot": str(shot) if shot.is_file() else "", "swatches": swatches, **colours}


def listing():
    def current(kind):
        link = HYPR / f"active-{kind}.lua"
        if not link.is_symlink():
            return ""
        t = Path(os.readlink(link))
        return t.parent.name if kind == "rice" else t.stem

    rices = sorted(d.name for d in (HYPR / "rices").iterdir() if (d / "theme.lua").is_file())
    # archonate first, then alphabetical
    rices.sort(key=lambda r: (r != "archonate", r))
    print(json.dumps({
        "rice": current("rice"),
        "mode": current("mode"),
        "rices": [preview(r) for r in rices],
        "styles": styles(),
        "style": current_style(),
        # rices that wear styles, each with its own current style and preview shots
        "styled": {r: {"style": current_style(r), "styles": styles(r)} for r in styled_rices()},
        "modes": sorted(f.stem for f in (HYPR / "modes").glob("*.lua")),
    }))


SPICETIFY_THEME = HOME / ".config/spicetify/Themes/hypr-rice"


def apply_spotify(rice, desk):
    """Spotify via Spicetify: one theme with a colour scheme per rice.
    Applied on every switch; Spotify restarts to load it, in the background,
    and picks the music back up if it was playing."""
    if not shutil.which("spicetify"):
        return
    p = desk.get("palette")
    if p:
        sections = []
        for d in sorted((HYPR / "rices").iterdir()):
            q = load_desktop(d.name).get("palette")
            if not q:
                continue
            sections.append("\n".join([
                f"[{d.name}]",
                f"text = {q['text']}", f"subtext = {q['text_dim']}", f"main = {q['bg']}",
                f"sidebar = {q['bg']}", f"player = {q['surface']}", f"card = {q['surface']}",
                f"shadow = 000000", f"selected-row = {q['text_dim']}", f"button = {q['accent']}",
                f"button-active = {q['accent']}", f"button-disabled = {q['surface_hi']}",
                f"tab-active = {q['surface_hi']}", f"notification = {q['surface_hi']}",
                f"notification-error = {q['error']}", f"misc = {q['surface_hi']}",
            ]))
        SPICETIFY_THEME.mkdir(parents=True, exist_ok=True)
        (SPICETIFY_THEME / "color.ini").write_text("\n\n".join(sections) + "\n")
        (SPICETIFY_THEME / "user.css").touch()
        run("spicetify", "config", "current_theme", "hypr-rice", "color_scheme", rice)
    detach(sys.executable, str(HYPR / "lib/desktop.py"), "spotify-reload")


MPRIS = ["--dest=org.mpris.MediaPlayer2.spotify", "/org/mpris/MediaPlayer2"]


def mpris_get(prop):
    """A Spotify MPRIS player property as raw dbus-send output ('' if unavailable)."""
    return subprocess.run(["dbus-send", "--print-reply", *MPRIS, "org.freedesktop.DBus.Properties.Get",
                           "string:org.mpris.MediaPlayer2.Player", f"string:{prop}"],
                          capture_output=True, text=True).stdout


def spotify_playing():
    return '"Playing"' in mpris_get("PlaybackStatus")


def spotify_position():
    import re
    m = re.search(r"int64 (\d+)", mpris_get("Position"))
    return int(m.group(1)) if m else None


def spotify_trackid():
    import re
    m = re.search(r'"mpris:trackid"\s*variant\s*(?:object path|string) "([^"]+)"', mpris_get("Metadata"))
    return m.group(1) if m else None


def spotify_reload():
    """Load the new Spicetify colours; restart Spotify only if it's open, then
    carry on playing from the same spot if it was playing."""
    import time
    # Live processes only: an exited Spotify can linger as a zombie
    running = subprocess.run(["pgrep", "-x", "-r", "R,S,D", "spotify"], capture_output=True).returncode == 0
    playing = running and spotify_playing()
    position = spotify_position() if playing else None
    if subprocess.run(["spicetify", "refresh", "-s", "-n", "-q"], capture_output=True).returncode != 0:
        # Spotify updated underneath Spicetify: re-patch from a fresh backup
        run("spicetify", "backup", "apply", "-n", "-q")
    if running:
        run("spicetify", "restart")
    if not playing:
        return
    # The client shows up on D-Bus before its player is ready and ignores
    # commands until a track is loaded, so wait for that, then nudge until it plays
    deadline = time.time() + 30
    while time.time() < deadline:
        time.sleep(1)
        track = spotify_trackid()
        if not track:
            continue
        if not spotify_playing():
            run("dbus-send", "--type=method_call", *MPRIS, "org.mpris.MediaPlayer2.Player.Play")
            continue
        now = spotify_position()
        if position and now is not None and abs(now - position) > 5_000_000:
            run("dbus-send", "--type=method_call", *MPRIS, "org.mpris.MediaPlayer2.Player.SetPosition",
                f"objpath:{track}" if track.startswith("/") else f"objpath:/org/mpris/MediaPlayer2/Track/0",
                f"int64:{position}")
        return


EFFECTS = STATE / "effects.json"
SETTINGS = STATE / "settings.json"
WALL_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".mp4", ".webm", ".mkv", ".mov"}

# Sounds offered in Rice Settings ("" = silent)
SOUNDS = [
    ("This rice's own", "rice:notify"),
    ("Silent", ""),
    ("Bell", "/usr/share/sounds/ocean/stereo/bell.oga"),
    ("Tick", "/usr/share/sounds/freedesktop/stereo/bell.oga"),
    ("Chime", "/usr/share/sounds/freedesktop/stereo/complete.oga"),
    ("Pop", "/usr/share/sounds/ocean/stereo/message-contact-in.oga"),
    ("Blip", "/usr/share/sounds/freedesktop/stereo/message.oga"),
    ("Highlight", "/usr/share/sounds/ocean/stereo/message-highlight.oga"),
    ("Message", "/usr/share/sounds/ocean/stereo/message-new-instant.oga"),
    ("Success", "/usr/share/sounds/ocean/stereo/completion-success.oga"),
    ("Attention", "/usr/share/sounds/ocean/stereo/message-attention.oga"),
]


def load_settings():
    try:
        return json.loads(SETTINGS.read_text())
    except (OSError, json.JSONDecodeError):
        return {}


def save_settings(s):
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    tmp = SETTINGS.with_suffix(".tmp")
    tmp.write_text(json.dumps(s, indent=2) + "\n")
    tmp.replace(SETTINGS)


def theme_defaults(rice):
    """The Theme.qml values Rice Settings can override."""
    import re
    out = {}
    f = shell_dir(rice) / "Theme.qml"
    if f.is_file():
        for key, val in re.findall(r"readonly property \w+ (notifSound|widgetPos|wallpaperMinutes): ([^\n]+)", f.read_text()):
            val = val.split("//")[0].strip()
            out[key] = int(val) if val.isdigit() else val.strip('"')
    return out


def wallpapers(rice):
    assets = HYPR / "rices" / rice / "assets"
    return [str(f) for f in sorted(assets.glob("wallpaper.*")) + sorted(assets.glob("wallpapers/*"))
            if f.suffix.lower() in WALL_EXTS]


def walls_info(rice=None):
    """For the wallpaper switcher: this rice's wallpapers (stills for videos),
    which one is showing, and the colours to draw the switcher in."""
    rice = rice or active_rice()
    cache = HOME / ".cache/hypr-rice/thumbs"
    items = []
    for w in wallpapers(rice):
        p = Path(w)
        thumb = w
        video = p.suffix.lower() in {".mp4", ".webm", ".mkv", ".mov"}
        if video:
            cache.mkdir(parents=True, exist_ok=True)
            thumb = str(cache / f"{rice}-{p.stem}.png")
            if not Path(thumb).is_file() or Path(thumb).stat().st_mtime < p.stat().st_mtime:
                run("ffmpeg", "-y", "-loglevel", "error", "-i", w, "-frames:v", "1", "-vf", "scale=640:-1", thumb)
        name = p.stem.replace("zz-", "").replace("-", " ").replace("_", " ")
        items.append({"path": w, "thumb": thumb, "video": video, "gif": p.suffix.lower() == ".gif", "name": name})
    try:
        cur = int((STATE / f"wall-{rice}").read_text())
    except (OSError, ValueError):
        cur = 0
    p = load_desktop(rice).get("palette", {})
    print(json.dumps({"rice": rice, "current": cur % max(1, len(items)), "items": items,
                      "accent": p.get("accent", "ffffff"), "bg": p.get("bg", "000000"), "text": p.get("text", "ffffff")}))


def rice_look(rice):
    """The active rice's look for apps drawn outside its shell (Settings, the
    menu): palette, plus font, corner radius, border weight, text casing and
    glass, read from its Theme.qml."""
    import re
    p = load_desktop(rice).get("palette", {})
    look = {"palette": p, "font": "Adwaita Sans", "radius": 12, "borderWidth": 1, "caps": "none", "glass": False}
    tq = shell_dir(rice) / "Theme.qml"
    if tq.is_file():
        t = tq.read_text()
        for key, rx, cast in (("font", r'property string font: "([^"]+)"', str),
                              ("radius", r'property int radius: (\d+)', int),
                              ("borderWidth", r'property int borderWidth: (\d+)', int)):
            m = re.search(rx, t)
            if m:
                look[key] = cast(m.group(1))
        m = re.search(r'function caps\(s: string\): string \{\s*return ([^;]+);', t)
        if m:
            body = m.group(1)
            look["caps"] = ("first" if "slice(1)" in body else "lower" if "toLowerCase" in body
                            else "upper" if "toUpperCase" in body else "none")
        look["glass"] = bool(re.search(r'property bool glass: true', t))
        m = re.search(r'property real tracking: ([\d.]+)', t)
        look["tracking"] = float(m.group(1)) if m else 0.0
        # border colour as rrggbbaa, from the forms the rices use:
        # pal.c("x") / Qt.alpha(pal.c("x"), a) / Qt.alpha("#rrggbb", a)
        m = re.search(r'property color border: ([^\n;]+)', t)
        if m:
            e = m.group(1)
            a = re.search(r'Qt\.alpha\((?:pal\.c\("(\w+)"\)|"#([0-9a-fA-F]{6})"),\s*([\d.]+)\)', e)
            if a:
                base = p.get(a.group(1), "") if a.group(1) else a.group(2)
                if base:
                    look["border"] = base.lower() + f"{round(float(a.group(3)) * 255):02x}"
            else:
                c = re.search(r'pal\.c\("(\w+)"\)', e)
                if c and p.get(c.group(1)):
                    look["border"] = p[c.group(1)].lower() + "ff"
    return look


# ---- day / night rices ----------------------------------------------------------
# global.schedule = {enabled, day: {rice, style}, night: {rice, style},
#                    followNightlight, dayFrom, nightFrom}
# The shell asks every minute (schedule_tick). It switches only when the period
# changes, so a rice picked by hand holds until the next change, and never
# while gaming mode is on.

SCHEDULE_LAST = STATE / "schedule-period"


def schedule_period(sc, g, now=None):
    if sc.get("followNightlight", True):
        n = g.get("nightlight", {})
        day_from, night_from = n.get("to", "07:00"), n.get("from", "20:00")
    else:
        day_from, night_from = sc.get("dayFrom", "07:00"), sc.get("nightFrom", "20:00")
    if now is None:
        from datetime import datetime
        now = datetime.now().strftime("%H:%M")
    if day_from < night_from:
        return "day" if day_from <= now < night_from else "night"
    return "night" if night_from <= now < day_from else "day"


def schedule_tick(force=False):
    g = load_settings().get("global", {})
    sc = g.get("schedule", {})
    if not sc.get("enabled"):
        return
    if active_mode() == "gaming":
        return  # never yank the desktop out from under a game
    period = schedule_period(sc, g)
    try:
        last = SCHEDULE_LAST.read_text().strip()
    except OSError:
        last = ""
    if period == last and not force:
        return
    SCHEDULE_LAST.write_text(period + "\n")
    want = sc.get(period) or {}
    rice, style = want.get("rice"), want.get("style")
    if not rice or not (HYPR / "rices" / rice / "theme.lua").is_file():
        return
    if is_styled(rice) and style and style_dir(style) and current_style(rice) != style:
        style_set(style, rice)
    if active_rice() != rice:
        run(str(HOME / ".local/bin/hypr-rice"), rice)
    print(f"schedule: {period} -> {rice}{' / ' + style if is_styled(rice) and style else ''}")


def schedule_status():
    g = load_settings().get("global", {})
    sc = g.get("schedule", {})
    print(json.dumps({"enabled": bool(sc.get("enabled")), "period": schedule_period(sc, g), **sc}))


def menu_data():
    """What the shell's Archonate menu lists, in one go (it asks on open)."""
    rices = sorted(d.name for d in (HYPR / "rices").iterdir() if (d / "theme.lua").is_file())
    cat = {}
    try:
        have = set(subprocess.run(["pacman", "-Qq"], capture_output=True, text=True).stdout.split())
    except OSError:
        have = set()
    for line in (HYPR / "lib/archonate/catalog.tsv").read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        sec, label, pkgs = parts[0], parts[1], parts[2]
        cat.setdefault(sec, []).append({"label": label, "pkgs": pkgs.split(),
                                        "after": parts[3] if len(parts) > 3 else "",
                                        "installed": all(p in have for p in pkgs.split())})
    # web apps and TUI launchers made with `archonate webapp|tui new`
    made = {"webapp": [], "tui": []}
    for kind in made:
        for f in sorted((HOME / ".local/share/applications").glob(f"archonate-{kind}-*.desktop")):
            name = next((l[5:] for l in f.read_text(errors="replace").splitlines() if l.startswith("Name=")), f.stem)
            made[kind].append(name)
    try:
        binds = []
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            keybinds_info()
        binds = json.loads(buf.getvalue())
    except Exception:
        binds = []
    print(json.dumps({
        "rice": active_rice(), "mode": active_mode(), "layout": current_layout(), "rices": rices,
        "modes": sorted(f.stem for f in (HYPR / "modes").glob("*.lua")),
        "style": current_style(style_rice()), "styleRice": style_rice(), "styled": styled_rices(),
        "styles": [{"name": x["name"], "title": x["title"], "accent": x["accent"], "mine": x["mine"]} for x in styles()],
        "keybinds": binds, "catalog": cat, "made": made,
    }))


def settings_info():
    """Everything the Rice Settings app shows, as JSON."""
    s = load_settings()
    try:
        eff = json.loads(EFFECTS.read_text())
    except (OSError, json.JSONDecodeError):
        eff = {}
    rices = []
    for r in sorted(d.name for d in (HYPR / "rices").iterdir() if (d / "theme.lua").is_file()):
        info = preview(r)
        if is_standalone(r):
            vals = {**theme_defaults(r), **s.get("rices", {}).get(r, {})}
            walls = wallpapers(r)
            try:
                idx = int((STATE / f"wall-{r}").read_text()) % max(1, len(walls))
            except (OSError, ValueError):
                idx = 0
            info.update(standalone=True, wallpapers=walls, wallIndex=idx,
                        assets=str(HYPR / "rices" / r / "assets"), **vals)
        else:
            info.update(standalone=False)
        rices.append(info)
    rices.sort(key=lambda r: (r["name"] != "archonate", r["name"]))
    link = lambda k: Path(os.readlink(HYPR / f"active-{k}.lua")) if (HYPR / f"active-{k}.lua").is_symlink() else None
    g = s.get("global", {})
    print(json.dumps({
        "rice": link("rice").parent.name if link("rice") else "",
        "mode": link("mode").stem if link("mode") else "",
        "modes": sorted(f.stem for f in (HYPR / "modes").glob("*.lua")),
        "rices": rices,
        "look": rice_look(link("rice").parent.name) if link("rice") else {},
        "sounds": [{"name": n, "path": p} for n, p in SOUNDS],
        "global": {
            "idleMinutes": 10, "screenOffMinutes": 15, "dnd": False, **g,
            "shader": eff.get("shader", True), "widgets": eff.get("widgets", True),
            "screensaver": eff.get("screensaver", True),
        },
    }))


def set_setting(scope, key, value):
    """desktop.py set global <key> <json> | set <rice> <key> <json>"""
    s = load_settings()
    v = json.loads(value)
    if scope == "global":
        s.setdefault("global", {})[key] = v
    else:
        s.setdefault("rices", {}).setdefault(scope, {})[key] = v
    save_settings(s)


def set_wallpaper(rice, index):
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / f"wall-{rice}").write_text(str(int(index)))
    run("qs", "-p", str(shell_dir(rice)), "ipc", "call", "rice", "rescanWallpaper")
    link = HYPR / "active-rice.lua"
    if link.is_symlink() and Path(os.readlink(link)).parent.name == rice:
        desk = load_desktop(rice)
        try:
            apply_login(rice)
            apply_newtab(rice, desk)
        except Exception as e:
            print(f"hypr-rice: {e}", file=sys.stderr)


def effect(name, action="toggle"):
    """shader / widgets / screensaver / intros on, off or toggle. Persisted in effects.json."""
    try:
        state = json.loads(EFFECTS.read_text())
    except (OSError, json.JSONDecodeError):
        state = {}
    cur = state.get(name, True)
    state[name] = {"on": True, "off": False}.get(action, not cur)
    EFFECTS.parent.mkdir(parents=True, exist_ok=True)
    EFFECTS.write_text(json.dumps(state) + "\n")

    link = HYPR / "active-rice.lua"
    rice = Path(os.readlink(link)).parent.name if link.is_symlink() else None
    if name == "shader":
        run("hyprctl", "reload")
    elif name == "widgets" and rice and is_standalone(rice):
        run("qs", "-p", str(shell_dir(rice)), "ipc", "call", "rice", "setWidgets", "true" if state[name] else "false")
    print(f"{name}: {'on' if state[name] else 'off'}")
    run_hook("toggle", name, "on" if state[name] else "off")


APP_CATEGORIES = [
    ("browser", "Web browser", ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"]),
    ("files", "Files", ["inode/directory"]),
    ("images", "Images", ["image/png", "image/jpeg", "image/gif", "image/webp"]),
    ("video", "Video", ["video/mp4", "video/x-matroska", "video/webm"]),
    ("music", "Music", ["audio/mpeg", "audio/flac", "audio/ogg"]),
    ("text", "Text", ["text/plain"]),
    ("pdf", "PDF", ["application/pdf"]),
]


def desktop_entries():
    """{id: {name, mimes, icon}} for launchable .desktop files (user ones win)."""
    import configparser
    dirs = [Path("/usr/share/applications"), Path("/var/lib/flatpak/exports/share/applications"),
            HOME / ".local/share/flatpak/exports/share/applications", HOME / ".local/share/applications"]
    out = {}
    for d in dirs:
        for f in sorted(d.glob("*.desktop")) if d.is_dir() else []:
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
                e = cp["Desktop Entry"]
            except Exception:
                continue
            if e.get("NoDisplay", "false").lower() == "true" or e.get("Type", "Application") != "Application":
                out.pop(f.name, None)
                continue
            out[f.name] = {"name": e.get("Name", f.stem), "icon": e.get("Icon", ""),
                           "mimes": [m for m in e.get("MimeType", "").split(";") if m]}
    return out


def apps_info():
    entries = desktop_entries()
    cats = []
    for key, label, mimes in APP_CATEGORIES:
        current = subprocess.run(["xdg-mime", "query", "default", mimes[0]], capture_output=True, text=True).stdout.strip()
        options = sorted(({"id": i, "name": e["name"], "icon": e["icon"]} for i, e in entries.items() if mimes[0] in e["mimes"]),
                         key=lambda o: o["name"].lower())
        cats.append({"key": key, "label": label, "current": current, "options": options})
    print(json.dumps(cats))


def set_app(key, desktop_id):
    mimes = next(m for k, _, m in APP_CATEGORIES if k == key)
    subprocess.run(["xdg-mime", "default", desktop_id, *mimes], check=True)


def about_info():
    import platform
    import re

    def read(p):
        try:
            return Path(p).read_text()
        except OSError:
            return ""

    osr = dict(re.findall(r'^(\w+)="?([^"\n]*)"?', read("/etc/os-release"), re.M))
    cpu = re.search(r"model name\s*:\s*(.+)", read("/proc/cpuinfo"))
    mem = re.search(r"MemTotal:\s+(\d+)", read("/proc/meminfo"))
    gpu = ""
    lspci = subprocess.run(["lspci"], capture_output=True, text=True).stdout
    for line in lspci.splitlines():
        if re.search(r"VGA|3D controller", line):
            g = re.search(r"\[(GeForce[^\]]*|Radeon[^\]]*|Arc[^\]]*)\]", line)
            gpu = g.group(1) if g else line.split(": ", 1)[-1]
    disk = shutil.disk_usage("/")
    up = float(read("/proc/uptime").split()[0] or 0)
    hypr = subprocess.run(["hyprctl", "version", "-j"], capture_output=True, text=True).stdout
    try:
        hv = json.loads(hypr).get("tag", "")
    except json.JSONDecodeError:
        hv = ""
    model = read("/sys/class/dmi/id/board_vendor").strip() + " " + read("/sys/class/dmi/id/board_name").strip()
    print(json.dumps({
        "host": platform.node(), "os": osr.get("PRETTY_NAME", "Linux"), "kernel": platform.release(),
        "cpu": cpu.group(1).strip() if cpu else "", "gpu": gpu,
        "memory": f"{int(mem.group(1)) / 1048576:.1f} GiB" if mem else "",
        "disk": f"{disk.used / 2**30:.0f} of {disk.total / 2**30:.0f} GiB used",
        "uptime": f"{int(up // 3600)} h {int(up % 3600 // 60)} min", "board": model.strip(),
        "hyprland": hv, "rice": symlink_rice(),
    }))


def symlink_rice():
    link = HYPR / "active-rice.lua"
    return Path(os.readlink(link)).parent.name if link.is_symlink() else ""


# ---- Settings app: shortcuts, updates, startup apps, storage, time, night light ----

EXTRA_BINDS = [
    ("Desktop", "SUPER + slash", "This cheat sheet"),
    ("Windows", "SUPER + BackSpace", "Layout: tiling, scrolling, floating"),
    ("Windows", "SUPER + H", "Minimize to the dock (floating layout)"),
    ("Desktop", "SUPER + Escape", "Archonate menu (everything)"),
    ("Desktop", "SUPER + F9", "Style picker"),
    ("Desktop", "SUPER + F10", "Mode picker"),
    ("Desktop", "SUPER + F12", "Desktop widget on/off"),
    ("Desktop", "SUPER + I", "Settings"),
    ("Clipboard & emoji", "SUPER + CTRL + SHIFT + V", "Forget the whole clipboard history"),
    ("Desktop", "SUPER + CTRL + W", "Wallpaper switcher"),
    ("Desktop", "SUPER + CTRL + Comma", "Notifications from the keyboard"),
    ("Desktop", "SUPER + CTRL + Print", "Copy text from the screen (OCR)"),
    ("Desktop", "SUPER + SHIFT + W", "Next wallpaper"),
    ("Desktop", "SUPER + SHIFT + ALT + W", "Previous wallpaper"),
    ("Windows", "SUPER + arrows", "Focus window in that direction"),
    ("Windows", "SUPER + SHIFT + arrows", "Move window in that direction"),
]


def keybinds_info():
    """Every keybind: the user's keymap from variables.lua (grouped by its
    section comments) plus the rice system's own binds."""
    import re
    src = (HYPR / "variables.lua").read_text()
    start = src.find("KEYBINDS")
    section = "Workspaces"
    rename = {"Window Actions": "Windows", "Window Group": "Window groups", "Special workspaces toggles": "Special workspaces",
              "Clipboard and emoji picker": "Clipboard & emoji", "Misc": "System"}
    rows = []
    for line in src[start:].splitlines():
        c = re.match(r"\s*--\s*(.+)", line)
        if c:
            text = c.group(1).strip()
            if not re.fullmatch(r"[-=]+", text) and not text.startswith(("Modifier", "All the following")):
                section = rename.get(text, text)
            continue
        m = re.match(r"\s*kb(\w+)\s*=\s*(.+?),?\s*$", line)
        if not m:
            continue
        name, val = m.groups()
        keys = re.findall(r'"([^"]+)"', val)
        if not keys:
            continue
        label = re.sub(r"(?<!^)(?=[A-Z])", " ", name).replace("Ws", "workspace").replace("Win ", "window ")
        label = label[0].upper() + label[1:].lower()
        if name in ("GoToWs", "MoveWinToWs", "GoToWsGroup", "MoveWinToWsGroup"):
            keys = [k + " + 1-0" for k in keys]
        rows.append({"group": section, "keys": keys, "label": label})
    rows = [{"group": g, "keys": [k], "label": l} for g, k, l in EXTRA_BINDS] + rows
    print(json.dumps(rows))


def updates_info():
    """Pending repo + AUR updates, and whether the running kernel was replaced."""
    def lines(cmd):
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        return [l for l in r.stdout.splitlines() if l.strip()]
    repo = lines(["checkupdates"])
    helper = shutil.which("paru") or shutil.which("yay")
    aur = lines([helper, "-Qua"]) if helper else []
    running = os.uname().release
    reboot = not Path(f"/usr/lib/modules/{running}").is_dir()
    def parse(l, src):
        p = l.split()
        return {"name": p[0], "from": p[1] if len(p) > 1 else "", "to": p[-1], "source": src}
    print(json.dumps({"repo": [parse(l, "repo") for l in repo], "aur": [parse(l, "aur") for l in aur],
                      "reboot": reboot, "kernel": running}))


AUTOSTART_USER = HOME / ".config/autostart"


def autostart_info():
    """XDG autostart entries that would run under Hyprland (uwsm starts these)."""
    import configparser
    found = {}
    for d in (Path("/etc/xdg/autostart"), AUTOSTART_USER):
        for f in sorted(d.glob("*.desktop")) if d.is_dir() else []:
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
                e = dict(cp["Desktop Entry"])
            except Exception:
                continue
            found[f.name] = (e, d == AUTOSTART_USER)
    out = []
    for name, (e, user) in found.items():
        only = [s for s in e.get("onlyshowin", "").split(";") if s]
        notin = [s for s in e.get("notshowin", "").split(";") if s]
        if (only and "Hyprland" not in only) or "Hyprland" in notin:
            continue
        enabled = e.get("hidden", "false").lower() != "true" and e.get("x-gnome-autostart-enabled", "true").lower() != "false"
        out.append({"file": name, "name": e.get("name", name), "comment": e.get("comment", ""),
                    "icon": e.get("icon", ""), "enabled": enabled, "user": user})
    out.sort(key=lambda o: o["name"].lower())
    print(json.dumps(out))


def autostart_set(file, action):
    """enable / disable via a user override in ~/.config/autostart; add <id> copies an app in."""
    AUTOSTART_USER.mkdir(parents=True, exist_ok=True)
    dst = AUTOSTART_USER / file
    if action == "add":
        for d in (HOME / ".local/share/applications", Path("/usr/share/applications")):
            if (d / file).is_file():
                shutil.copy2(d / file, dst)
                return
        raise SystemExit(f"no such app: {file}")
    src = dst if dst.is_file() else Path("/etc/xdg/autostart") / file
    lines = [l for l in src.read_text().splitlines() if not l.startswith("Hidden=")]
    if action == "disable":
        i = lines.index("[Desktop Entry]") + 1 if "[Desktop Entry]" in lines else 0
        lines.insert(i, "Hidden=true")
    dst.write_text("\n".join(lines) + "\n")
    if action == "remove":
        dst.unlink(missing_ok=True)


def storage_info():
    """Disks, biggest folders in home, and what can be cleaned."""
    disks = []
    seen = set()
    for line in Path("/proc/mounts").read_text().splitlines():
        dev, mnt, fs = line.split()[:3]
        if not dev.startswith("/dev/") or dev in seen or mnt.startswith(("/boot", "/var/lib", "/snap")):
            continue
        seen.add(dev)
        try:
            u = shutil.disk_usage(mnt)
        except OSError:
            continue
        disks.append({"mount": mnt, "fs": fs, "used": u.used, "total": u.total})

    def du(path):
        r = subprocess.run(["du", "-sxb", str(path)], capture_output=True, text=True, timeout=120)
        try:
            return int(r.stdout.split()[0])
        except (IndexError, ValueError):
            return 0

    folders = []
    for p in sorted(HOME.iterdir()):
        if p.is_dir() and not p.is_symlink():
            folders.append({"name": p.name, "size": du(p)})
    folders.sort(key=lambda f: -f["size"])
    orphans = subprocess.run(["pacman", "-Qtdq"], capture_output=True, text=True).stdout.split()
    print(json.dumps({
        "disks": disks, "folders": folders[:12],
        "pacmanCache": du("/var/cache/pacman/pkg"), "paruCache": du(HOME / ".cache/paru"),
        "orphans": orphans,
    }))


def time_info():
    r = subprocess.run(["timedatectl", "show"], capture_output=True, text=True).stdout
    d = dict(l.split("=", 1) for l in r.splitlines() if "=" in l)
    zones = subprocess.run(["timedatectl", "list-timezones"], capture_output=True, text=True).stdout.split()
    print(json.dumps({"timezone": d.get("Timezone", ""), "ntp": d.get("NTP") == "yes",
                      "synced": d.get("NTPSynchronized") == "yes", "zones": zones}))


NIGHT_CONF = HYPR / "hyprsunset.conf"


def nightlight_apply():
    """Write hyprsunset's schedule from settings.json and (re)start it."""
    n = load_settings().get("global", {}).get("nightlight", {})
    run("pkill", "-x", "hyprsunset")
    if not n.get("enabled") or not shutil.which("hyprsunset"):
        return
    NIGHT_CONF.write_text(
        "# Written by Rice Settings (Night light)\n"
        f"profile {{\n    time = {n.get('to', '07:00')}\n    identity = true\n}}\n\n"
        f"profile {{\n    time = {n.get('from', '20:00')}\n    temperature = {n.get('temp', 4000)}\n}}\n")
    detach("hyprsunset")  # reads ~/.config/hypr/hyprsunset.conf by itself


# ---- styles --------------------------------------------------------------------
# A rice that has a look.json wears styles: downloaded dark themes (imported by
# lib/archonate/import-styles.py into ~/.local/share/archonate/styles), the
# ones shipped in lib/styles/, and any made from a wallpaper. A style becomes
# the rice's desktop.json (palette, ANSI, folders), its fuzzel.ini and its
# wallpapers folder; look.json adds the rice's own fonts, corners and launcher
# shape. Each styled rice remembers its own style.

STYLES = HOME / ".local/share/archonate/styles"
SHIPPED_STYLES = HYPR / "lib/styles"
DEFAULT_STYLE = "tokyo-night"


def styled_rices():
    return sorted(d.name for d in (HYPR / "rices").iterdir() if (d / "look.json").is_file())


def is_styled(rice):
    return (HYPR / "rices" / rice / "look.json").is_file()


def rice_look_json(rice):
    return json.loads((HYPR / "rices" / rice / "look.json").read_text())


def style_dir(name):
    """Yours win over the shipped ones of the same name."""
    for base in (STYLES, SHIPPED_STYLES):
        if (base / name / "style.json").is_file():
            return base / name
    return None


def style_state(rice):
    return STATE / rice


def styles(rice="archonate"):
    out, seen = [], set()
    for base in (STYLES, SHIPPED_STYLES):
        for d in sorted(base.glob("*/style.json")):
            try:
                s = json.loads(d.read_text())
            except (OSError, json.JSONDecodeError):
                continue
            if s["name"] in seen:
                continue
            seen.add(s["name"])
            bgdir = d.parent / "backgrounds"
            bgs = sorted(p for p in bgdir.iterdir() if p.suffix.lower() in WALL_EXTS) if bgdir.is_dir() else []
            p = s["palette"]
            shot = STATE / "previews" / f"{rice}-{s['name']}.png"
            out.append({"name": s["name"], "title": s.get("title", s["name"]), "bg": p["bg"], "accent": p["accent"],
                        "text": p["text"], "wallpaper": str(bgs[0]) if bgs else "",
                        "shot": str(shot) if shot.is_file() else "", "mine": s.get("source") == "wallpaper",
                        "swatches": [p[k] for k in ("bg", "surface", "surface_hi", "text_dim", "text", "accent", "secondary", "tertiary")]})
    out.sort(key=lambda s: s["name"])
    return out


def default_style(rice):
    try:
        want = rice_look_json(rice).get("default_style", DEFAULT_STYLE)
    except (OSError, json.JSONDecodeError):
        want = DEFAULT_STYLE
    if style_dir(want):
        return want
    have = [s["name"] for s in styles(rice)]
    return DEFAULT_STYLE if DEFAULT_STYLE in have else (have[0] if have else "")


def current_style(rice="archonate"):
    try:
        name = (style_state(rice) / "style").read_text().strip()
    except OSError:
        name = ""
    return name if name and style_dir(name) else default_style(rice)


def _write_in_place(path, text):
    """Rewrite without replacing the file, so watchers following it keep working."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as fh:
        fh.write(text)


def build_style(name, rice="archonate"):
    """Make `rice` wear style `name`: desktop.json, fuzzel.ini, wallpapers."""
    sdir = style_dir(name)
    s = json.loads((sdir / "style.json").read_text())
    p = s["palette"]
    look = rice_look_json(rice)
    desk = {**look.get("desktop", {}), "palette": p, "ansi": s["ansi"],
            "folders": s.get("folders", "blue"), "style": name}
    st = style_state(rice)
    _write_in_place(st / "desktop.json", json.dumps(desk, indent=4) + "\n")
    f = {"font": "JetBrainsMono Nerd Font:size=12", "width": 40, "lines": 10, "hpad": 20, "vpad": 16,
         "ipad": 10, "alpha": "f2", "border": 2, "radius": 6, **look.get("fuzzel", {})}
    _write_in_place(st / "fuzzel.ini", f"""# {rice} launcher ({s.get('title', name)})
[main]
font={f['font']}
prompt="  "
icon-theme=Papirus-Dark
width={f['width']}
lines={f['lines']}
horizontal-pad={f['hpad']}
vertical-pad={f['vpad']}
inner-pad={f['ipad']}

[colors]
background={p['bg']}{f['alpha']}
text={p['text']}ff
prompt={p['accent']}ff
placeholder={p['text_dim']}ff
input={p['text']}ff
match={p['accent']}ff
selection={p['surface_hi']}ff
selection-text={p['text']}ff
selection-match={p['accent']}ff
border={p['accent']}{f.get('border_alpha', 'ff')}

[border]
width={f['border']}
radius={f['radius']}
""")
    root = HYPR / "rices" / rice
    links = {root / "desktop.json": st / "desktop.json",
             root / "fuzzel.ini": st / "fuzzel.ini",
             root / "assets/wallpapers": sdir / "backgrounds"}
    for link, target in links.items():
        if link.is_symlink() or not link.exists():
            if link.is_symlink() and Path(os.readlink(link)) == target:
                continue
            link.parent.mkdir(parents=True, exist_ok=True)
            tmp = link.with_name(link.name + ".new")
            if tmp.is_symlink() or tmp.exists():
                tmp.unlink()
            tmp.symlink_to(target)
            tmp.replace(link)
    _write_in_place(st / "style", name + "\n")
    return desk


def style_rice():
    """The rice style commands mean: the active one if it takes styles, else archonate."""
    r = active_rice()
    return r if r and is_styled(r) else "archonate"


def style_set(name, rice=None):
    """Dress `rice` (default: the active rice if it takes styles, else archonate)."""
    if not style_dir(name):
        raise SystemExit(f"no style {name!r}; run 'archonate style list' (or 'archonate style import')")
    rice = rice or style_rice()
    if not is_styled(rice):
        raise SystemExit(f"the {rice} rice doesn't take styles (these do: {', '.join(styled_rices())})")
    changed = current_style(rice) != name
    desk = build_style(name, rice)
    if changed:
        (STATE / f"wall-{rice}").write_text("0")  # start on the style's first wallpaper
    if active_rice() == rice:
        apply_gtk(desk)
        apply_cursor(desk)
        apply_kitty(desk)
        run("hyprctl", "reload")
        run("qs", "-p", str(shell_dir(rice)), "ipc", "call", "rice", "rescanWallpaper")
        detach(sys.executable, str(HYPR / "lib/desktop.py"), "swap-rest", rice)
    print(f"style: {name}" + ("" if rice == "archonate" else f" ({rice})"))
    run_hook("style-set", name, rice)


def style_list(rice="archonate"):
    cur = current_style(rice)
    for s in styles(rice):
        print(("* " if s["name"] == cur else "  ") + s["name"])


def status_info():
    """The whole desktop's state in one object, for `archonate status --json`."""
    rice = active_rice()
    s = load_settings()
    try:
        eff = json.loads(EFFECTS.read_text())
    except (OSError, json.JSONDecodeError):
        eff = {}
    try:
        version = subprocess.run(["git", "-C", str(HYPR), "describe", "--tags", "--always", "--dirty"],
                                 capture_output=True, text=True).stdout.strip()
    except OSError:
        version = ""
    rices = sorted(d.name for d in (HYPR / "rices").iterdir() if (d / "theme.lua").is_file())
    return {
        "version": version,
        "rice": rice,
        "mode": active_mode(),
        "style": current_style(rice) if is_styled(rice) else None,
        "rices": rices,
        "styledRices": styled_rices(),
        "styles": [x["name"] for x in styles(rice if is_styled(rice) else "archonate")],
        "modes": sorted(f.stem for f in (HYPR / "modes").glob("*.lua")),
        "toggles": {k: toggle_state(k) for k in TOGGLES},
        "riceSettings": {**theme_defaults(rice), **s.get("rices", {}).get(rice, {})},
        "globalSettings": s.get("global", {}),
        "effects": eff,
    }


# ---- hooks -------------------------------------------------------------------
# Your own scripts, run after Archonate events: ~/.config/archonate/hooks/<event>
# and every file in ~/.config/archonate/hooks/<event>.d/ (*.sample skipped).
# Events: theme-set <rice>, mode-set <mode>, style-set <style>, toggle <name> <on|off>,
#         post-update, post-boot.

HOOKS = HOME / ".config/archonate/hooks"
HOOK_EVENTS = ["theme-set", "mode-set", "style-set", "layout-set", "toggle", "post-update", "post-boot"]


def run_hook(event, *args):
    if event not in HOOK_EVENTS:
        raise SystemExit(f"unknown hook {event!r}; one of {', '.join(HOOK_EVENTS)}")
    single = HOOKS / event
    scripts = [single] if single.is_file() else []
    d = HOOKS / f"{event}.d"
    if d.is_dir():
        scripts += sorted(p for p in d.iterdir() if p.is_file() and p.suffix != ".sample")
    for s in scripts:
        r = subprocess.run(["bash", str(s), *args])
        if r.returncode:
            print(f"archonate: hook failed: {s}", file=sys.stderr)


# ---- window layouts ----------------------------------------------------------
# tiling (dwindle), scrolling (Hyprland's own) or floating (every window floats,
# with a dock), for the whole desktop. hyprland/layouts.lua reads LAYOUT_FILE at
# config load; switching here applies it live. Floating = archonate_float_rule
# on (new windows) + floating the open ones; each window it floats is tagged
# archonate-floated, so leaving floating tiles exactly those again.

LAYOUTS = ["tiling", "scrolling", "floating"]
LAYOUT_FILE = STATE / "layout"
LAYOUT_TAG = "archonate-floated"
MINIMIZED = "special:minimized"


def current_layout():
    try:
        name = LAYOUT_FILE.read_text().strip()
    except OSError:
        return "tiling"
    return name if name in LAYOUTS else "tiling"


def _hyprctl(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True).stdout


def _clients():
    try:
        return json.loads(_hyprctl("clients", "-j"))
    except json.JSONDecodeError:
        return []


def _dispatch(expr):
    _hyprctl("dispatch", expr)


def _active_ws():
    try:
        return json.loads(_hyprctl("activeworkspace", "-j"))["id"]
    except (json.JSONDecodeError, KeyError):
        return 1


def _keeps_floating(c):
    """Windows that float on their own (picture-in-picture, dialogs and apps
    the rules float): leaving floating mode doesn't tile them."""
    tags = c.get("tags") or []
    return c.get("pinned") or any(t.rstrip("*").startswith(("float", "xwl_popup")) for t in tags)


def _float_all():
    _hyprctl("eval", "_G.archonate_float_rule:set_enabled(true)")
    for c in _clients():
        if c.get("mapped", True) and not c["floating"] and not c["workspace"]["name"].startswith("special"):
            a = c["address"]
            _dispatch(f"hl.dsp.window.tag({{ tag = '+{LAYOUT_TAG}', window = 'address:{a}' }})")
            _dispatch(f"hl.dsp.window.float({{ action = 'set', window = 'address:{a}' }})")


def _tile_back():
    _hyprctl("eval", "_G.archonate_float_rule:set_enabled(false)")
    ws = _active_ws()
    for c in _clients():
        a = c["address"]
        if c["workspace"]["name"] == MINIMIZED:  # nothing shows them without the dock
            _dispatch(f"hl.dsp.window.move({{ workspace = '{ws}', window = 'address:{a}', follow = false }})")
        tags = [t.rstrip("*") for t in c.get("tags") or []]
        if LAYOUT_TAG in tags:
            _dispatch(f"hl.dsp.window.tag({{ tag = '-{LAYOUT_TAG}', window = 'address:{a}' }})")
            if c["floating"] and not _keeps_floating(c):
                _dispatch(f"hl.dsp.window.float({{ action = 'unset', window = 'address:{a}' }})")


LAYOUT_LOOK = {"tiling": ("dashboard", "Tiling"), "scrolling": ("view_column", "Scrolling"),
               "floating": ("filter_none", "Floating")}


def layout_set(name):
    if name not in LAYOUTS:
        raise SystemExit(f"unknown layout {name!r}; one of {', '.join(LAYOUTS)}")
    prev = current_layout()
    atomic_write(LAYOUT_FILE, name + "\n")
    if prev == "floating" and name != "floating":
        _tile_back()
    _hyprctl("eval", f'hl.config({{ general = {{ layout = "{"scrolling" if name == "scrolling" else "dwindle"}" }} }})')
    if name == "floating" and prev != "floating":
        _float_all()
    icon, label = LAYOUT_LOOK[name]
    run("qs", "-p", str(shell_dir(active_rice())), "ipc", "call", "rice", "announce", icon, label)
    run_hook("layout-set", name)


def layout_next():
    layout_set(LAYOUTS[(LAYOUTS.index(current_layout()) + 1) % len(LAYOUTS)])


def window_minimize(address=None):
    """Park a window in the floating dock (a hidden workspace)."""
    if current_layout() != "floating":
        run("notify-send", "-a", "archonate", "Minimize works in floating mode",
            "Switch with Super + Backspace; the dock holds minimized windows.")
        return
    target = f"address:{address}" if address else "active"
    if not address:
        w = json.loads(_hyprctl("activewindow", "-j") or "{}")
        if not w.get("address"):
            return
        target = f"address:{w['address']}"
    _dispatch(f"hl.dsp.window.move({{ workspace = '{MINIMIZED}', window = '{target}', follow = false }})")


def window_restore(address):
    """Back from the dock to the workspace you're on, focused."""
    ws = _active_ws()
    _dispatch(f"hl.dsp.window.move({{ workspace = '{ws}', window = 'address:{address}', follow = false }})")
    _dispatch(f"hl.dsp.focus({{ window = 'address:{address}' }})")


# ---- toggles -----------------------------------------------------------------
# One switch, one code path: the bar, quick panels, keybinds, the menu and the
# Settings app all call `archonate toggle <name>`, and the shell watches the
# files these write, so every view of a switch updates together.

TOGGLES = {
    "nightlight": ("Night light", "nightlight"),
    "dnd": ("Do not disturb", "do_not_disturb_on"),
    "caffeine": ("Keep awake", "coffee"),
    "gaming": ("Gaming mode", "sports_esports"),
    "widgets": ("Desktop widget", "widgets"),
    "shader": ("Screen shader", "auto_awesome"),
    "screensaver": ("Screensaver", "animation"),
    "intros": ("Wallpaper intros", "movie"),
}


def active_mode():
    link = HYPR / "active-mode.lua"
    return Path(os.readlink(link)).stem if link.is_symlink() else "normal"


def toggle_state(name):
    g = load_settings().get("global", {})
    if name == "nightlight":
        return bool(g.get("nightlight", {}).get("enabled"))
    if name in ("dnd", "caffeine"):
        return bool(g.get(name))
    if name == "gaming":
        return active_mode() == "gaming"
    try:
        return json.loads(EFFECTS.read_text()).get(name, True)
    except (OSError, json.JSONDecodeError):
        return True


def toggle(name, action="toggle"):
    if name not in TOGGLES:
        raise SystemExit(f"unknown toggle {name!r}; one of {', '.join(TOGGLES)}")
    if action == "status":
        print("on" if toggle_state(name) else "off")
        return
    on = {"on": True, "off": False}.get(action, not toggle_state(name))

    if name == "nightlight":
        s = load_settings()
        n = s.setdefault("global", {}).setdefault("nightlight", {})
        n["enabled"] = on
        save_settings(s)
        nightlight_apply()
        if on:
            # Warm now, not only from the evening: hyprsunset applies its
            # schedule once it has booted, so keep asking until it sticks
            t = n.get("temp", 4000)
            detach("sh", "-c", f"for i in $(seq 15); do sleep 0.3; hyprctl hyprsunset temperature {t} >/dev/null 2>&1; done")
    elif name in ("dnd", "caffeine"):
        set_setting("global", name, json.dumps(on))
    elif name == "gaming":
        run(str(HOME / ".local/bin/hypr-mode"), "gaming" if on else "normal")
    else:
        effect(name, "on" if on else "off")
        return  # effect() reports and runs its hook

    print(f"{name}: {'on' if on else 'off'}")
    run_hook("toggle", name, "on" if on else "off")


def toggles_info():
    print(json.dumps([{"id": k, "label": l, "icon": i, "on": toggle_state(k)} for k, (l, i) in TOGGLES.items()]))


def main(argv):
    if len(argv) in (3, 4) and argv[1] == "effect" and argv[2] in ("shader", "widgets", "screensaver", "intros"):
        effect(*argv[2:])
    elif len(argv) in (3, 4) and argv[1] == "toggle":
        toggle(*argv[2:])
    elif len(argv) in (2, 3) and argv[1] == "walls":
        walls_info(*argv[2:])
    elif len(argv) in (3, 4) and argv[1] == "style":
        style_set(*argv[2:])
    elif len(argv) in (2, 3) and argv[1] == "styles":
        r = argv[2] if len(argv) == 3 else style_rice()
        print(json.dumps({"rice": r, "current": current_style(r), "styles": styles(r), "styled": styled_rices()}))
    elif len(argv) in (2, 3) and argv[1] == "style-list":
        style_list(argv[2] if len(argv) == 3 else style_rice())
    elif len(argv) in (2, 3) and argv[1] == "style-current":
        print(current_style(argv[2] if len(argv) == 3 else style_rice()))
    elif len(argv) == 2 and argv[1] == "status":
        print(json.dumps(status_info(), indent=2))
    elif len(argv) in (2, 3) and argv[1] == "style-rice":
        print(style_rice())
    elif len(argv) in (2, 3) and argv[1] == "style-build":
        r = argv[2] if len(argv) == 3 else style_rice()
        build_style(current_style(r), r)
    elif len(argv) in (2, 3) and argv[1] == "schedule-tick":
        schedule_tick(force=len(argv) == 3 and argv[2] == "--force")
    elif len(argv) == 2 and argv[1] == "schedule":
        schedule_status()
    elif len(argv) == 2 and argv[1] == "menu-data":
        menu_data()
    elif len(argv) == 3 and argv[1] == "layout" and argv[2] == "next":
        layout_next()
    elif len(argv) == 3 and argv[1] == "layout" and argv[2] == "current":
        print(current_layout())
    elif len(argv) == 4 and argv[1] == "layout" and argv[2] == "set":
        layout_set(argv[3])
    elif len(argv) in (2, 3) and argv[1] == "window-minimize":
        window_minimize(argv[2] if len(argv) == 3 else None)
    elif len(argv) == 3 and argv[1] == "window-restore":
        window_restore(argv[2])
    elif len(argv) == 2 and argv[1] == "toggles":
        toggles_info()
    elif len(argv) >= 3 and argv[1] == "hook":
        run_hook(*argv[2:])
    elif len(argv) == 2 and argv[1] == "welcome":
        # "first" exactly once per user: the shell greets a first login
        flag = STATE / "welcomed"
        if flag.exists():
            print("seen")
        else:
            flag.parent.mkdir(parents=True, exist_ok=True)
            flag.touch()
            print("first")
    elif len(argv) == 2 and argv[1] == "claude":
        rice = active_rice()
        apply_claude(rice, load_desktop(rice))
    elif len(argv) == 2 and argv[1] == "spotify":
        rice = active_rice()
        apply_spotify(rice, load_desktop(rice))
    elif len(argv) == 2 and argv[1] == "keybinds":
        keybinds_info()
    elif len(argv) == 2 and argv[1] == "updates":
        updates_info()
    elif len(argv) == 2 and argv[1] == "autostart":
        autostart_info()
    elif len(argv) == 4 and argv[1] == "autostart":
        autostart_set(argv[2], argv[3])
    elif len(argv) == 2 and argv[1] == "storage":
        storage_info()
    elif len(argv) == 2 and argv[1] == "time":
        time_info()
    elif len(argv) == 2 and argv[1] == "nightlight":
        nightlight_apply()
    elif len(argv) == 2 and argv[1] == "apps":
        apps_info()
    elif len(argv) == 4 and argv[1] == "setapp":
        set_app(argv[2], argv[3])
    elif len(argv) == 2 and argv[1] == "about":
        about_info()
    elif len(argv) == 2 and argv[1] == "settings":
        settings_info()
    elif len(argv) == 5 and argv[1] == "set":
        set_setting(*argv[2:])
    elif len(argv) == 4 and argv[1] == "wallpaper":
        set_wallpaper(argv[2], argv[3])
    elif len(argv) == 2 and argv[1] == "spotify-reload":
        spotify_reload()
    elif len(argv) == 2 and argv[1] == "list":
        listing()
    elif len(argv) == 4 and argv[1] == "swap":
        swap(argv[2], argv[3])
    elif len(argv) == 3 and argv[1] == "swap-rest":
        swap_rest(argv[2])
    elif len(argv) == 3 and argv[1] == "mode":
        mode(argv[2])
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
