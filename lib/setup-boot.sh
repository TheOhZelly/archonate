#!/usr/bin/env bash
# The ARCHONATE boot menu (Limine): Archonate's colours, its logo as the
# wallpaper, "ARCHONATE LINUX" on top, no help clutter. Run with sudo:
#   sudo ~/.config/hypr/lib/setup-boot.sh install   # theme the boot menu
#   sudo ~/.config/hypr/lib/setup-boot.sh undo      # back to exactly how it was
#   sudo ~/.config/hypr/lib/setup-boot.sh status
#
# It only touches the global settings at the top of limine.conf (between two
# marker lines), never the boot entries, and comments out any setting of yours
# it replaces (undo puts them back). With Secure Boot, limine.conf's hash is
# enrolled into the signed Limine binary: this re-enrolls and re-signs it with
# CachyOS's own limine-enroll-config, as CachyOS says to after any edit, and
# puts the old file back if that fails. A wallpaper Limine can't verify is
# skipped, never fatal.
set -euo pipefail

# (ARCHONATE_LIMINE_DEFAULTS + ARCHONATE_BOOT_TEST=1: try it on a copy, without root)
[ "$(id -u)" = 0 ] || [ "${ARCHONATE_BOOT_TEST:-}" = 1 ] || { echo "run with sudo: sudo $0 ${1:-install}" >&2; exit 1; }
user=${SUDO_USER:-}
hypr=${ARCHONATE_HYPR:-$(cd "$(dirname "$0")/.." && pwd)}
defaults=${ARCHONATE_LIMINE_DEFAULTS:-/etc/default/limine}
# only the two settings needed, read rather than sourced (the file holds bash
# arrays like KERNEL_CMDLINE[default]+=... that aren't ours to evaluate)
setting() { [ -r "$defaults" ] && sed -n "s/^[[:space:]]*$1=[\"']\{0,1\}\([^\"']*\)[\"']\{0,1\}[[:space:]]*\$/\1/p" "$defaults" | tail -1; }
ESP_PATH=$(setting ESP_PATH)
ENABLE_ENROLL_LIMINE_CONFIG=$(setting ENABLE_ENROLL_LIMINE_CONFIG)
esp=${ESP_PATH:-/boot}
conf="$esp/limine.conf"
mark_begin="# >>> archonate boot theme (lib/setup-boot.sh; undo: sudo setup-boot.sh undo)"
mark_end="# <<< archonate boot theme"
off="#archonate-off# "
wall="$esp/archonate/boot.png"
keys='wallpaper|wallpaper_style|backdrop|interface_branding|interface_branding_colou?r|interface_help_hidden|term_palette|term_palette_bright|term_background|term_foreground|term_background_bright|term_foreground_bright|term_margin|term_margin_gradient'

[ -f "$conf" ] || { echo "no Limine config at $conf (is this a Limine system? ESP_PATH in /etc/default/limine)" >&2; exit 1; }

# re-enroll limine.conf's hash (and sign) when this system enrolls it
enroll() {
    [ "${ENABLE_ENROLL_LIMINE_CONFIG:-no}" = yes ] || return 0
    command -v limine-enroll-config >/dev/null || { echo "ENABLE_ENROLL_LIMINE_CONFIG=yes but no limine-enroll-config" >&2; return 1; }
    limine-enroll-config
}

# remove our block and un-comment what it replaced
strip() {
    sed -i "/^$(printf '%s' "$mark_begin" | sed 's/[][\.*^$/]/\\&/g')\$/,/^$(printf '%s' "$mark_end" | sed 's/[][\.*^$/]/\\&/g')\$/d" "$1"
    sed -i "s/^$off//" "$1"
}

case "${1:-status}" in
    install)
        command -v python3 >/dev/null && python3 -c 'import PIL' 2>/dev/null || { echo "needs python-pillow" >&2; exit 1; }
        backup="$conf.bak-archonate"
        cp -p "$conf" "$backup"
        new=$(mktemp)
        cp "$conf" "$new"
        strip "$new"
        # the wallpaper: the logo under the menu, on the built-in style's background
        mkdir -p "$(dirname "$wall")"
        # Sized for this screen's boot resolution: Limine's margins are in
        # pixels, and the logo sits inside the bottom margin, where the menu
        # never writes, so a long menu can't run into it.
        res=$(tr ',' 'x' </sys/class/graphics/fb0/virtual_size 2>/dev/null || true)
        [[ $res =~ ^[0-9]+x[0-9]+$ ]] || res=1920x1080
        H=${res#*x}
        margin=$((H * 15 / 100))
        python3 -I "$hypr/lib/archonate/boot-splash.py" --size "$res" --logo-height 0.075 \
            --y "$(awk -v h="$H" -v m="$margin" 'BEGIN{printf "%.4f", (h - m * 0.25) / h}')" \
            "$hypr/lib/archonate/logo.txt" "$wall" >/dev/null
        hash=$(b2sum "$wall" | cut -d' ' -f1)
        rel=${wall#"$esp"}
        # comment out the settings of yours this replaces (global section only: before the first entry)
        awk -v keys="^($keys):" -v off="$off" '
            /^\// { entries = 1 }
            !entries && $0 ~ keys { print off $0; next }
            { print }' "$new" >"$new.2" && mv "$new.2" "$new"
        {
            echo "$mark_begin"
            cat <<EOF
interface_branding: A R C H O N A T E   L I N U X
interface_branding_colour: 8fa4b2
interface_help_hidden: yes
wallpaper: boot():$rel#$hash
wallpaper_style: stretched
backdrop: 141618
term_background: ff141618
term_foreground: c8ccce
term_background_bright: 2d3135
term_foreground_bright: e3e6e7
term_palette: 141618;c2756e;7f948a;b3a68c;8fa4b2;a294b5;8fa4b2;c8ccce
term_palette_bright: 656c71;d6948d;9fb3a9;cbbe9f;aebfcb;b9adc9;aebfcb;e3e6e7
term_margin: $margin
term_margin_gradient: 0
EOF
            echo "$mark_end"
            cat "$new"
        } >"$new.3"
        cp "$new.3" "$conf"
        rm -f "$new" "$new.3"
        if ! enroll; then
            echo "re-enrolling failed: putting the old limine.conf back" >&2
            cp -p "$backup" "$conf"
            enroll || echo "!! the old config couldn't be re-enrolled either; run: sudo limine-enroll-config" >&2
            exit 1
        fi
        echo "boot menu themed ($conf; backup: $backup). See it on the next boot."
        ;;
    undo)
        grep -qF "$mark_begin" "$conf" || { echo "not themed; nothing to undo"; exit 0; }
        cp -p "$conf" "$conf.bak-archonate-undo"
        strip "$conf"
        rm -f "$wall"; rmdir "$(dirname "$wall")" 2>/dev/null || true
        if ! enroll; then
            echo "re-enrolling failed: restoring the themed config" >&2
            cp -p "$conf.bak-archonate-undo" "$conf"; enroll || true
            exit 1
        fi
        echo "boot menu back to how it was"
        ;;
    status)
        if grep -qF "$mark_begin" "$conf"; then echo "themed ($conf)"; else echo "not themed ($conf)"; fi
        echo "config enrollment (Secure Boot): ${ENABLE_ENROLL_LIMINE_CONFIG:-no}"
        ;;
    *) echo "usage: sudo $0 install|undo|status" >&2; exit 2 ;;
esac
