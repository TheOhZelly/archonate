#!/usr/bin/env bash
# Power menu for standalone rices: session.sh <rice>
rice=$1
dir="$HOME/.config/hypr"
choice=$(printf '%s\n' lock logout suspend reboot shutdown |
    fuzzel --dmenu --config "$dir/rices/$rice/fuzzel.ini" --lines 5 --width 20 --prompt "session  ") || exit 0
case "$choice" in
    lock) qs -p "$dir/rices/$rice/shell" ipc call rice lock ;;
    logout) if command -v uwsm >/dev/null; then uwsm stop; else loginctl terminate-session "$XDG_SESSION_ID"; fi ;;
    suspend) systemctl suspend-then-hibernate ;;
    reboot) systemctl reboot ;;
    shutdown) systemctl poweroff ;;
esac
