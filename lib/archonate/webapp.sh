# Web apps and TUI launchers that Archonate makes: shared bits. Sourced.
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/archonate/app-icons"

# ask "prompt" -> what you typed (fuzzel in the rice's look; empty = cancelled)
ask() {
    local cfg="$HYPR_DIR/rices/$(current_rice)/fuzzel.ini"
    [ -f "$cfg" ] || cfg=""
    fuzzel --dmenu ${cfg:+--config "$cfg"} --prompt-only "$1  " </dev/null 2>/dev/null
}

# pick "prompt" lines... -> the chosen line
pick_one() {
    local cfg="$HYPR_DIR/rices/$(current_rice)/fuzzel.ini" p=$1; shift
    [ -f "$cfg" ] || cfg=""
    printf '%s\n' "$@" | fuzzel --dmenu ${cfg:+--config "$cfg"} --prompt "$p  " --lines "$(( $# < 12 ? $# : 12 ))" 2>/dev/null
}

slugify() { tr '[:upper:]' '[:lower:]' <<<"$1" | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//'; }

# desktop-entry Exec quoting: % doubles, and " ` $ \ get a backslash
exec_quote() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; s=${s//\`/\\\`}; s=${s//\$/\\\$}; printf '"%s"' "${s//%/%%}"; }

# list <kind> -> "name<TAB>file" for each one Archonate made
list_made() {
    local f
    for f in "$APPS"/archonate-"$1"-*.desktop; do
        [ -f "$f" ] || continue
        printf '%s\t%s\n' "$(sed -n 's/^Name=//p' "$f" | head -1)" "$f"
    done
}

refresh_launcher() { update-desktop-database "$APPS" >/dev/null 2>&1 || true; }
