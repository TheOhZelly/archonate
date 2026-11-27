# Shared logic for hypr-rice and hypr-mode. Sourced, not executed.
# Caller sets KIND (rice|mode) then calls: switch_main "$@"

HYPR_DIR="${HOME}/.config/hypr"
ACTIVE="${HYPR_DIR}/active-${KIND}.lua"

# Path of a layer file relative to HYPR_DIR
layer_path() {
    case "$KIND" in
        rice) echo "rices/$1/theme.lua" ;;
        mode) echo "modes/$1.lua" ;;
    esac
}

list_names() {
    case "$KIND" in
        rice) for d in "$HYPR_DIR"/rices/*/theme.lua; do basename "$(dirname "$d")"; done ;;
        mode) for f in "$HYPR_DIR"/modes/*.lua; do basename "$f" .lua; done ;;
    esac
}

current_name() {
    local t
    t=$(readlink "$ACTIVE" 2>/dev/null) || return 0
    case "$KIND" in
        rice) t=${t#rices/}; echo "${t%/theme.lua}" ;;
        mode) t=${t#modes/}; echo "${t%.lua}" ;;
    esac
}

notify() {
    command -v notify-send >/dev/null && notify-send -a "hypr-$KIND" "$@" || true
}


show_list() {
    local cur n
    cur=$(current_name)
    while read -r n; do
        if [ "$n" = "$cur" ]; then echo "* $n"; else echo "  $n"; fi
    done < <(list_names)
}

# Hold a still of the current desktop over every screen while the rice swaps
# underneath; the new shell fades it (cover/shell.qml). Skipped when
# animations are off or grim is missing.
cover_up() {
    command -v grim >/dev/null || return 0
    local dir=${XDG_RUNTIME_DIR:-/tmp} mon
    for mon in $(hyprctl -j monitors | python3 -c 'import json,sys; print(" ".join(m["name"] for m in json.load(sys.stdin)))'); do
        grim -o "$mon" "$dir/archonate-cover-$mon.png" 2>/dev/null &
    done
    wait
    qs -p "$HYPR_DIR/cover" kill >/dev/null 2>&1
    qs -p "$HYPR_DIR/cover" -d >/dev/null 2>&1
    # Wait (briefly) until it's actually on screen before changing anything
    for _ in $(seq 20); do
        hyprctl layers 2>/dev/null | grep -q archonate-cover && break
        sleep 0.05
    done
    # Fallback fade, in case the new shell never asks
    (sleep 4; qs -p "$HYPR_DIR/cover" ipc call cover fade >/dev/null 2>&1) 9>&- &
}

# hyprctl reload, then report configerrors (empty = clean)
reload_errors() {
    hyprctl reload >/dev/null 2>&1
    sleep 0.4
    hyprctl configerrors 2>/dev/null | sed '/^[[:space:]]*$/d'
}

switch_to() {
    local name=$1 rel prev prev_name errs
    rel=$(layer_path "$name")
    if [ ! -f "$HYPR_DIR/$rel" ]; then
        echo "hypr-$KIND: no such $KIND '$name'. Available:" >&2
        list_names | sed 's/^/  /' >&2
        return 1
    fi

    prev=$(readlink "$ACTIVE" 2>/dev/null)
    prev_name=$(current_name)
    [ "$KIND" = rice ] && [ "$prev_name" != "$name" ] && cover_up
    ln -sfn "$rel" "$ACTIVE"

    errs=$(reload_errors)
    if [ -n "$errs" ]; then
        echo "hypr-$KIND: config errors after switching to '$name', rolling back:" >&2
        echo "$errs" >&2
        if [ -n "$prev" ]; then ln -sfn "$prev" "$ACTIVE"; reload_errors >/dev/null; fi
        notify -u critical "Failed to switch $KIND to $name" "Rolled back. Run hyprctl configerrors."
        return 1
    fi

    # Swap the running desktop (shells, GTK, cursor, kitty) / tell it the mode
    case "$KIND" in
        rice) [ "$prev_name" != "$name" ] && python3 "$HYPR_DIR/lib/desktop.py" swap "${prev_name:-archonate}" "$name" ;;
        mode) python3 "$HYPR_DIR/lib/desktop.py" mode "$name" ;;
    esac

    case "$KIND" in
        rice) python3 "$HYPR_DIR/lib/desktop.py" hook theme-set "$name" ;;
        mode) python3 "$HYPR_DIR/lib/desktop.py" hook mode-set "$name" ;;
    esac
    echo "$KIND -> $name"
    # Let the new shell take the notification bus first, without making the
    # caller wait for it
    if [ -n "${ARCHONATE_QUIET:-}" ]; then
        :
    elif [ "$KIND" = rice ]; then
        (sleep 1; notify "$KIND: $name" "Applied.") 9>&- &
    else
        notify "$KIND: $name" "Applied."
    fi
}

switch_main() {
    # One switch at a time: a second click waits instead of racing the first
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/archonate-switch.lock"
    flock 9
    case "${1:-}" in
        "" | -l | --list) show_list ;;
        -p | --pick)
            local choice
            choice=$(list_names | fuzzel --dmenu --prompt "$KIND > " --lines "$(list_names | wc -l)") || exit 0
            [ -n "$choice" ] && switch_to "$choice"
            ;;
        --spotify) python3 "$HYPR_DIR/lib/desktop.py" spotify ;;
        --effect) python3 "$HYPR_DIR/lib/desktop.py" effect "$2" "${3:-toggle}" ;;
        -h | --help) echo "usage: hypr-$KIND [name | --pick | --list | --effect shader|screensaver|intros [on|off|toggle]]" ;;
        *) switch_to "$1" ;;
    esac
}
