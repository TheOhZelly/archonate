#!/usr/bin/env bash
# Emoji/glyph picker for standalone rices: emoji.sh <rice>. Copies the choice.
# The emoji list lives in lib/templates.
list="$HOME/.config/hypr/lib/templates/emojis.txt"
chosen=$(fuzzel --dmenu --config "$HOME/.config/hypr/rices/$1/fuzzel.ini" --prompt "emoji  " \
    --placeholder "Type to search emojis" <"$list") || exit 0
printf '%s' "${chosen%% *}" | wl-copy
