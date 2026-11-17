#!/usr/bin/env bash
# Screenshots, recordings and screen text for every rice.
#   capture.sh shot | region | text | record | record-sound | record-region
# text: select an area, its text (OCR, tesseract) goes to the clipboard.
# Screenshots go to ~/Pictures/Screenshots and the clipboard; recordings to
# ~/Videos/Recordings. Running a record mode again stops the recording.
shots="$HOME/Pictures/Screenshots"
recs="$HOME/Videos/Recordings"
stamp=$(date +%Y-%m-%d_%H-%M-%S)
mkdir -p "$shots" "$recs"

notify() { command -v notify-send >/dev/null && notify-send -a capture "$@"; }

# The rice's shutter sound, unless desktop sounds are off in Settings
sfx() {
    local rice snd
    rice=$(readlink "$HOME/.config/hypr/active-rice.lua" | cut -d/ -f2)
    snd="$HOME/.config/hypr/rices/$rice/assets/sounds/$1.oga"
    [ "$(jq -r '.global.uiSounds // true' "$HOME/.local/state/hypr-rice/settings.json" 2>/dev/null)" = false ] && return
    [ -f "$snd" ] && (pw-play "$snd" &) 2>/dev/null
}

case "$1" in
    shot)
        f="$shots/$stamp.png"
        grim "$f" && sfx shot && wl-copy <"$f" && notify "Screenshot saved" "$f"
        ;;
    region)
        geo=$(slurp) || exit 0
        f="$shots/$stamp.png"
        grim -g "$geo" "$f" && sfx shot && wl-copy <"$f" && notify "Screenshot saved" "$f"
        ;;
    text)
        geo=$(slurp) || exit 0
        langs=$(tesseract --list-langs 2>/dev/null | tail -n +2 | grep -vx osd | paste -sd+)
        # 2x capture: tesseract reads small UI text much better when it's bigger
        txt=$(grim -g "$geo" -s 2 -t png - | tesseract stdin stdout -l "${langs:-eng}" 2>/dev/null |
            sed -e 's/[[:space:]]*$//' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
        if [ -z "${txt//[[:space:]]/}" ]; then
            notify "No text found" "Try a tighter selection"
            exit 0
        fi
        printf '%s' "$txt" | wl-copy
        sfx shot
        notify "Text copied" "$(printf '%s' "$txt" | head -c 160)"
        ;;
    record | record-sound | record-region)
        if pkill -INT -x gpu-screen-recorder; then
            notify "Recording saved" "$recs"
            exit 0
        fi
        mon=$(hyprctl -j monitors | python3 -c 'import json,sys;print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))')
        args=(-w "$mon" -f 60)
        if [ "$1" = record-region ]; then
            geo=$(slurp -f '%wx%h+%x+%y') || exit 0
            args=(-w region -region "$geo" -f 60)
        fi
        [ "$1" = record-sound ] && args+=(-a default_output)
        notify "Recording" "Press the same key again to stop"
        gpu-screen-recorder "${args[@]}" -o "$recs/$stamp.mp4"
        ;;
esac
