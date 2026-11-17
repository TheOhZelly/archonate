#!/usr/bin/env bash
# Archonate in one line, on Arch Linux or anything built on it:
#
#   curl -fsSL https://raw.githubusercontent.com/TheOhZelly/archonate/master/boot.sh | bash
#
# Gets git if it's missing, puts Archonate at ~/.config/hypr (your old Hyprland
# config is moved aside to ~/.config/hypr.bak-<date>, never deleted), then runs
# its installer, which asks before anything big. Already have Archonate there?
# It updates it instead. Extra arguments go to the installer (bash -s -- --yes).
#
# ARCHONATE_REPO and ARCHONATE_REF pick another fork or branch.

# Everything inside main, so a download cut off halfway runs nothing
main() {
    set -euo pipefail
    local repo=${ARCHONATE_REPO:-https://github.com/TheOhZelly/archonate.git}
    local ref=${ARCHONATE_REF:-master}
    local hypr="$HOME/.config/hypr"

    say() { printf '\e[1;34m==>\e[0m \e[1m%s\e[0m\n' "$*"; }
    die() { printf '\e[1;31m==>\e[0m %s\n' "$*" >&2; exit 1; }

    printf '\n\e[1m   A R C H O N A T E\e[0m\n\n'
    [ "$(id -u)" -ne 0 ] || die "Run this as yourself, not root: it asks for sudo when it needs it."
    command -v pacman >/dev/null || die "Archonate needs Arch Linux or a distro built on it (it installs with pacman)."

    if ! command -v git >/dev/null; then
        say "Installing git"
        sudo pacman -S --needed --noconfirm git
    fi

    if [ -d "$hypr/.git" ] && git -C "$hypr" remote -v 2>/dev/null | grep -qi archonate; then
        say "Archonate is already at $hypr: updating it"
        git -C "$hypr" pull --ff-only
    else
        if [ -e "$hypr" ]; then
            local bak
            bak="$hypr.bak-$(date +%Y%m%d-%H%M%S)"
            say "Moving your current Hyprland config to $bak"
            mv "$hypr" "$bak"
        fi
        say "Getting Archonate"
        mkdir -p "$HOME/.config"
        git clone --branch "$ref" "$repo" "$hypr"
    fi

    say "Running the installer"
    # Piped from curl, stdin is this script: give the installer the terminal
    # so it can ask its questions (no terminal at all: it takes the defaults).
    if [ -t 1 ] && { : </dev/tty; } 2>/dev/null; then
        exec "$hypr/install.sh" "$@" </dev/tty
    else
        exec "$hypr/install.sh" "$@"
    fi
}

main "$@"
