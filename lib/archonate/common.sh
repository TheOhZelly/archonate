# Sourced by archonate commands.
HYPR_DIR="${HYPR_DIR:-$HOME/.config/hypr}"
ARCHONATE_PY="${ARCHONATE_PY:-$HYPR_DIR/lib/desktop.py}"
BIN="$HOME/.local/bin"

current_rice() { readlink "$HYPR_DIR/active-rice.lua" 2>/dev/null | cut -d/ -f2; }
current_mode() { basename "$(readlink "$HYPR_DIR/active-mode.lua" 2>/dev/null)" .lua; }
rice_names() { for d in "$HYPR_DIR"/rices/*/theme.lua; do basename "$(dirname "$d")"; done; }
standalone() { true; } # every rice runs its own shell

# Call the running rice shell's IPC: shell_ipc <function> [args]
shell_ipc() {
    qs -p "$HYPR_DIR/rices/$(current_rice)/shell" ipc call rice "$@"
}

# The AUR helper that's installed: paru, else yay (both take the same flags
# we use). Empty when there is none; repo packages still work through pacman.
AUR_HELPER=$(command -v paru || command -v yay || true)
AUR_HELPER=${AUR_HELPER##*/}

notify() { command -v notify-send >/dev/null && notify-send -a archonate "$@" || true; }
