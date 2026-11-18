#!/usr/bin/env bash
# Archonate on Arch Linux or anything built on it (CachyOS, EndeavourOS, ...).
#
#   curl -fsSL https://raw.githubusercontent.com/TheOhZelly/archonate/master/boot.sh | bash
#
# or by hand:
#   mv ~/.config/hypr ~/.config/hypr.bak 2>/dev/null   # keep what was there
#   git clone https://github.com/TheOhZelly/archonate ~/.config/hypr
#   ~/.config/hypr/install.sh
#
# Safe to run again. Asks for your password for packages. Every file of yours
# it edits (~/.zshrc, kitty.conf) is backed up first, and it says so. The
# system-level extras (login screen, Brave policy) are printed at the end to
# run yourself. `install.sh --yes` takes the defaults without asking.
set -euo pipefail
HYPR="$HOME/.config/hypr"
YES=false
[ "${1:-}" = --yes ] && YES=true
# --yes also means no package prompts (paru: no PKGBUILD review either)
NOCONFIRM=()
$YES && NOCONFIRM=(--noconfirm)

[ "$(id -u)" -ne 0 ] || { echo "run this as yourself, not root (it asks for sudo when it needs it)" >&2; exit 1; }
[ "$(cd "$(dirname "$0")" && pwd)" = "$HYPR" ] || { echo "clone this repo to $HYPR first (see the top of this file)" >&2; exit 1; }
command -v pacman >/dev/null || { echo "Archonate installs with pacman: it needs Arch Linux or a distro built on it" >&2; exit 1; }

step() { printf '\n\e[1;34m==>\e[0m \e[1m%s\e[0m\n' "$*"; }
note() { printf '    \e[2m%s\e[0m\n' "$*"; }
# ask "question" [default y|n] -> 0 for yes. --yes or no terminal: the default.
ask() {
    local d=${2:-n} a
    if $YES || [ ! -t 0 ]; then [ "$d" = y ]; return; fi
    read -rp "    $1 [$([ "$d" = y ] && echo Y/n || echo y/N)] " a
    case "${a:-$d}" in [yY]*) return 0 ;; *) return 1 ;; esac
}
# backup <file>: one dated copy before the first edit of this run
STAMP=$(date +%F)
backup() {
    [ -f "$1" ] || return 0
    local b="$1.bak-archonate-$STAMP"
    [ -e "$b" ] || { cp -p "$1" "$b"; note "backed up $1 -> ${b##*/}"; }
}

# ARCHONATE_SKIP_PACKAGES=1: the packages are already there (the Archonate ISO
# and its installer put them in place); do everything else.
if [ -n "${ARCHONATE_SKIP_PACKAGES:-}" ]; then
    step "Packages"
    note "already installed (ARCHONATE_SKIP_PACKAGES)"
    AUR=$(command -v paru || command -v yay || true)
    skipped=()
else
# ---- AUR helper ------------------------------------------------------------
step "AUR helper"
AUR=$(command -v paru || command -v yay || true)
if [ -z "$AUR" ]; then
    note "A few packages come from the AUR (screen recorder, cursors, Spotify theming)."
    if ask "No paru or yay found. Build and install paru now?" y; then
        sudo pacman -S --needed --noconfirm base-devel git
        tmp=$(mktemp -d)
        git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
        (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
        AUR=$(command -v paru)
    else
        note "Carrying on with pacman only; AUR packages are skipped and listed at the end."
    fi
else
    note "using ${AUR##*/}"
fi

# ---- packages --------------------------------------------------------------
step "Packages"
repo=(
    # desktop
    hyprland uwsm quickshell fuzzel kitty thunar hyprsunset hyprpicker xdg-utils gtk3
    qt6-declarative qt6-multimedia qt6-imageformats
    # sound, network, bluetooth, power (what the bar's panels talk to)
    pipewire pipewire-audio wireplumber networkmanager bluez-utils power-profiles-daemon upower
    brightnessctl ddcutil
    # capture, clipboard, OCR, media
    grim slurp wl-clipboard cliphist wtype tesseract tesseract-data-eng ffmpeg
    # what the scripts lean on
    python python-pillow jq fzf libnotify dart-sass btop fastfetch pciutils pacman-contrib git curl
    # looks
    papirus-icon-theme ttf-material-symbols-variable ttf-jetbrains-mono-nerd
    noto-fonts adwaita-fonts ttf-fira-sans
    # the archonate rice: its visualizer
    cava
    # the shell: zsh with Archonate's prompt (lib/zsh), its plugins and tools
    zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
    zsh-theme-powerlevel10k eza zoxide
    # desktop basics: home folders, USB drives and phones in Thunar, thumbnails,
    # archives, a video player, image and PDF viewers, saved passwords, CJK
    # text, Windows/camera disks, firmware updates
    xdg-user-dirs inetutils gvfs gvfs-mtp thunar-volman thunar-archive-plugin file-roller
    tumbler ffmpegthumbnailer unzip 7zip wget mpv imv zathura zathura-pdf-mupdf
    gnome-keyring libsecret seahorse noto-fonts-cjk ntfs-3g exfatprogs fwupd man-pages
)
# the AUR (or CachyOS's repos for some), so they go through the helper
aur=(gpu-screen-recorder whitesur-cursor-theme-git ttf-rubik-vf)
skipped=()
if [ -n "$AUR" ]; then
    "$AUR" -S --needed "${NOCONFIRM[@]}" $($YES && [[ $AUR == *paru ]] && echo --skipreview) "${repo[@]}" "${aur[@]}"
else
    sudo pacman -S --needed "${NOCONFIRM[@]}" "${repo[@]}"
    skipped+=("${aur[@]}")
fi

# ---- optional apps ---------------------------------------------------------
step "Apps (optional)"
note "The app keys open your defaults: SUPER+W browser, SUPER+E files, SUPER+SHIFT+E editor."
extra=()
has_any() { local c; for c in "$@"; do command -v "$c" >/dev/null && return 0; done; return 1; }
has_any firefox brave brave-origin chromium zen-browser librewolf || { ask "No browser found. Install Firefox?" y && extra+=(firefox) || true; }
has_any zeditor code codium kate gnome-text-editor || { ask "No editor found. Install Zed?" y && extra+=(zed) || true; }
has_any pwvucontrol pavucontrol || { ask "Install a sound mixer (pwvucontrol)?" y && extra+=(pwvucontrol) || true; }
if [ -n "$AUR" ]; then
    if has_any spotify spotify-launcher; then
        command -v spicetify >/dev/null || { ask "Spotify found. Install spicetify so it follows the rice?" y && extra+=(spicetify-bin) || true; }
    fi
    command -v claude-desktop >/dev/null || { ask "Install the Claude app (claude-desktop-extra, a community build that follows the rice)?" n && extra+=(claude-desktop-extra) || true; }
fi
if [ ${#extra[@]} -gt 0 ]; then
    ${AUR:-sudo pacman} -S --needed "${NOCONFIRM[@]}" $($YES && [[ ${AUR:-} == *paru ]] && echo --skipreview) "${extra[@]}"
else
    note "nothing to add"
fi

fi

# ---- commands ----------------------------------------------------------------
step "Commands in ~/.local/bin"
mkdir -p "$HOME/.local/bin"
ln -sfn "$HYPR/bin/hypr-rice" "$HOME/.local/bin/hypr-rice"
ln -sfn "$HYPR/bin/hypr-mode" "$HOME/.local/bin/hypr-mode"
ln -sfn "$HYPR/lib/archonate/archonate" "$HOME/.local/bin/archonate"
note "archonate, hypr-rice, hypr-mode"
"$HOME/.local/bin/archonate" apps install | sed 's/^/    /'

step "Your folders"
# Desktop, Downloads, Pictures, ... (screenshots, recordings and the browser use them)
if command -v xdg-user-dirs-update >/dev/null; then xdg-user-dirs-update && note "$(cd ~ && ls -d Desktop Documents Downloads Music Pictures Videos 2>/dev/null | tr '\n' ' ')"; else note "xdg-user-dirs not installed"; fi

# ---- terminal ----------------------------------------------------------------
step "Kitty follows the rice"
kc="$HOME/.config/kitty/kitty.conf"
mkdir -p "${kc%/*}"
if ! grep -qs '^include rice.conf' "$kc" || ! grep -qs '^confirm_os_window_close' "$kc"; then
    backup "$kc"
    touch "$kc"
    grep -q '^include rice.conf' "$kc" || printf '\ninclude rice.conf\n' >>"$kc"
    grep -q '^confirm_os_window_close' "$kc" || echo 'confirm_os_window_close 0' >>"$kc"
    note "added 2 lines to kitty.conf"
else
    note "already set"
fi

# ---- shell ---------------------------------------------------------------------
step "Your shell"
case "${SHELL##*/}" in
    zsh)
        rc="$HOME/.zshrc"
        lines=()
        grep -qs 'local/bin' "$rc" || lines+=('path=(~/.local/bin $path)')
        zsh_line='source ~/.config/hypr/lib/zsh/archonate.zsh   # Archonate: prompt, plugins, completion'
        use_zsh=false
        if ! grep -qs 'lib/zsh/archonate.zsh' "$rc" && ask "Use Archonate's zsh (its own prompt theme, suggestions, highlighting, completion)?" y; then
            use_zsh=true
            # (an older install sourced lib/prompt.zsh directly: archonate.zsh does that now)
            grep -qs 'lib/prompt.zsh' "$rc" || lines+=("$zsh_line")
        fi
        fetch_line='source ~/.config/hypr/lib/fetch.zsh 2>/dev/null && archonate_fetch || fastfetch'
        swap_fetch=false
        if ! grep -qs 'lib/fetch.zsh' "$rc" && ask "Show fastfetch with the ARCHONATE logo in new terminals?" y; then
            if grep -qs '^fastfetch$' "$rc"; then swap_fetch=true; else lines+=("$fetch_line"); fi
        fi
        if [ ${#lines[@]} -gt 0 ] || $swap_fetch || { $use_zsh && grep -qs 'lib/prompt.zsh' "$rc"; }; then
            backup "$rc"
            touch "$rc"
            if $swap_fetch; then sed -i "s#^fastfetch\$#${fetch_line//&/\\&}#" "$rc"; fi
            if $use_zsh && grep -qs 'lib/prompt.zsh' "$rc"; then sed -i "s|^.*lib/prompt\.zsh.*\$|${zsh_line//&/\\&}|" "$rc"; fi
            if [ ${#lines[@]} -gt 0 ]; then { printf '\n# Archonate\n'; printf '%s\n' "${lines[@]}"; } >>"$rc"; fi
            note "edited ~/.zshrc"
        else
            note "nothing to change in ~/.zshrc"
        fi
        ;;
    *)
        rc="$HOME/.bashrc"
        [ "${SHELL##*/}" = bash ] || rc="$HOME/.profile"
        if ! grep -qs 'local/bin' "$rc"; then
            backup "$rc"
            printf '\n# Archonate\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$rc"
            note "added ~/.local/bin to PATH in ${rc##*/}"
        fi
        note "The themed prompt and the fastfetch shine are zsh-only; everything else works in ${SHELL##*/}."
        ;;
esac

# ---- CachyOS's update tray --------------------------------------------------------
# cachy-update autostarts a tray icon and a daily "updates available" timer.
# Archonate's bar has its own update badge and panel (archonate update), so
# both are switched off for this user; package updates don't bring them back.
if pacman -Q cachy-update >/dev/null 2>&1; then
    step "CachyOS's update tray (the bar has its own)"
    mkdir -p "$HOME/.config/autostart"
    printf '[Desktop Entry]\nType=Application\nName=Cachy-Update Systray Applet\n# Archonate: off. The bar has its own update badge (archonate update).\nHidden=true\n' \
        > "$HOME/.config/autostart/arch-update-tray.desktop"
    systemctl --user mask --now arch-update.timer >/dev/null 2>&1 || true
    note "tray icon and update reminders off (undo: rm ~/.config/autostart/arch-update-tray.desktop; systemctl --user unmask arch-update.timer)"
fi

# ---- yours -----------------------------------------------------------------------
step "Styles for archonate (a set of dark themes, plus its own)"
if [ -n "${ARCHONATE_NO_IMPORT:-}" ]; then note "skipped for now (later: archonate style import)"; else
    "$HOME/.local/bin/archonate" style import || note "couldn't fetch styles now; later: archonate style import"
fi
# dress every rice that wears styles (offline, archonate wears its own built-in style)
for r in $(python3 "$HYPR/lib/desktop.py" styles | jq -r '.styled[]'); do
    python3 "$HYPR/lib/desktop.py" style-build "$r" || note "couldn't dress $r yet; later: archonate style set <style> $r"
done

step "Your overrides and first rice"
[ -e "$HYPR/user.lua" ] || { cp "$HYPR/user.lua.example" "$HYPR/user.lua"; note "user.lua created (your own keys, layouts, autostart; git ignores it)"; }
[ -L "$HYPR/active-rice.lua" ] || ln -sfn rices/archonate/theme.lua "$HYPR/active-rice.lua"
[ -L "$HYPR/active-mode.lua" ] || ln -sfn modes/normal.lua "$HYPR/active-mode.lua"
note "rice: $(readlink "$HYPR/active-rice.lua" | cut -d/ -f2), mode: $(basename "$(readlink "$HYPR/active-mode.lua")" .lua)"

step "Your coding agents"
# Archonate's skills (how to drive this desktop, how to diagnose a crash) go to
# every AI coding tool you have; tools installed later get them on the next
# 'archonate update' or 'archonate agent skills'.
if [ -f "$HOME/.config/archonate/agent-skills-off" ]; then
    note "skipped: you turned them off (archonate agent skills on)"
else
    note "$("$HOME/.local/bin/archonate" agent skills on 2>&1 | tail -1)"
fi
note "SUPER+A opens your coding agent; it already knows Archonate, so just ask"

step "Check"
"$HOME/.local/bin/archonate" doctor --quiet || true

cat <<'DONE'

Done. Log into Hyprland (the "Hyprland (uwsm-managed)" session), then:

    SUPER + /         every keyboard shortcut
    SUPER + Escape    the Archonate menu: rices, wallpapers, settings, everything

Optional, system-level (run them yourself; each has --undo or uninstall):
  sudo ~/.config/hypr/lib/setup-root.sh            # Brave toolbar follows the rice
  sudo pacman -S sddm
  sudo ~/.config/hypr/lib/setup-login.sh install   # the ARCHONATE login screen
  sudo ~/.config/hypr/lib/setup-login.sh switch
  sudo ~/.config/hypr/lib/setup-branding.sh        # CachyOS only: call the system "Archonate Linux"
DONE
if [ ${#skipped[@]} -gt 0 ]; then
    printf '\nSkipped (AUR, no helper): %s\n  Without them: no screen recording, default cursors. Install paru or yay, then run this again.\n' "${skipped[*]}"
fi
