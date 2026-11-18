#!/usr/bin/env bash
# The Archonate menu: everything the desktop can do, in one searchable tree,
# drawn by fuzzel in the active rice's style. SUPER+Escape, or
#   archonate menu [rice|mode|wallpaper|toggles|capture|panels|settings|keys|update|power|install|remove]
. "$ARCHONATE_DIR/common.sh"

A="$BIN/archonate"
rice=$(current_rice)
cfg="$HYPR_DIR/rices/$rice/fuzzel.ini"
[ -f "$cfg" ] || cfg=""

# pick <prompt> <lines...>  -> the chosen line (empty on Escape)
pick() {
    local prompt=$1; shift
    local n=$#; [ "$n" -gt 14 ] && n=14
    printf '%s\n' "$@" | fuzzel --dmenu ${cfg:+--config "$cfg"} --prompt "$prompt  " --lines "$n" --width 34 --no-sort --with-nth=1 2>/dev/null
}

strip() { sed -E 's/^[^[:alnum:]]*[[:space:]]+//; s/[[:space:]]+[●○].*$//' <<<"$1"; }

# One rice (the shipped setup): picking a rice means picking a style
solo() { [ "$(rice_names | wc -l)" -le 1 ]; }

menu_rice() {
    solo && { menu_style; return; }
    local cur lines=() r c
    cur=$(current_rice)
    while read -r r; do
        [ "$r" = "$cur" ] && lines+=("󰏘   $r   ●") || lines+=("󰏘   $r")
    done < <(rice_names)
    c=$(pick "rice" "󰏘   Visual picker" "󰏘   Styles for $(python3 "$ARCHONATE_PY" style-rice) (omarchy themes)" "${lines[@]}") || return
    case "$c" in
        *"Visual picker"*) "$A" theme pick ;;
        *"Styles for "*) menu_style ;;
        ?*) "$A" theme set "$(strip "$c")" ;;
    esac
}

menu_style() {
    local cur lines=() c
    cur=$("$ARCHONATE_DIR/cmd/style-current")
    while IFS=$'\t' read -r name title; do
        [ "$name" = "$cur" ] && lines+=("󰏘   $title   ●	$name") || lines+=("󰏘   $title	$name")
    done < <(python3 "$ARCHONATE_PY" styles | python3 -c '
import json, sys
for s in json.load(sys.stdin)["styles"]: print(s["name"], s["title"], sep="\t")')
    mine=$(python3 "$ARCHONATE_PY" styles | python3 -c '
import json, sys
print(sum(1 for s in json.load(sys.stdin)["styles"] if s.get("mine")))')
    [ "$mine" -gt 0 ] && lines+=("󰆴   Remove a style you made	-remove")
    c=$(pick "style" "󰏘   Visual picker	-pick" "${lines[@]}") || return
    case "${c##*$'\t'}" in
        -pick) "$A" theme pick ;;
        -remove) menu_style_remove ;;
        ?*) "$A" style set "${c##*$'\t'}" ;;
    esac
}

menu_style_remove() {
    local cur lines=() c
    cur=$("$ARCHONATE_DIR/cmd/style-current")
    while IFS=$'\t' read -r name title; do
        [ "$name" = "$cur" ] || lines+=("󰆴   $title	$name")
    done < <(python3 "$ARCHONATE_PY" styles | python3 -c '
import json, sys
for s in json.load(sys.stdin)["styles"]:
    if s.get("mine"): print(s["name"], s["title"], sep="\t")')
    [ ${#lines[@]} -gt 0 ] || { notify-send "Archonate" "No styles of yours to remove (you can't remove the one you're wearing)"; return; }
    c=$(pick "remove style" "${lines[@]}") || return
    [ -n "$c" ] && "$A" style remove "${c##*$'\t'}" && notify-send "Archonate" "Style moved to the trash"
}

menu_mode() {
    local cur c
    cur=$(current_mode)
    c=$(pick "mode" "$( [ "$cur" = normal ] && echo "󰘮   normal   ●" || echo "󰘮   normal")" \
        "$( [ "$cur" = gaming ] && echo "󰊗   gaming   ●" || echo "󰊗   gaming")" \
        "$( [ "$cur" = minimal ] && echo "󰊓   minimal   ●" || echo "󰊓   minimal")") || return
    [ -n "$c" ] && "$A" mode set "$(strip "$c")"
}

menu_wallpaper() {
    local c
    c=$(pick "wallpaper" "󰋩   Switcher" "󰒭   Next" "󰒮   Previous" "󰝰   Open the folder" "󰋩   Wallpaper settings") || return
    case "$c" in
        *Switcher*) "$A" wallpaper pick ;;
        *Next*) "$A" wallpaper next ;;
        *Previous*) "$A" wallpaper prev ;;
        *folder*) xdg-open "$HYPR_DIR/rices/$rice/assets/wallpapers" 2>/dev/null || xdg-open "$HYPR_DIR/rices/$rice/assets" ;;
        *settings*) "$A" settings wallpaper ;;
    esac
}

menu_toggles() {
    local lines=() c
    while IFS=$'\t' read -r id on label; do
        lines+=("$([ "$on" = True ] && echo "●" || echo "○")  $label	$id")
    done < <(python3 "$ARCHONATE_PY" toggles | python3 -c '
import json, sys
for t in json.load(sys.stdin): print(t["id"], t["on"], t["label"], sep="\t")')
    c=$(pick "switch" "${lines[@]}") || return
    [ -n "$c" ] && "$A" toggle "${c##*$'\t'}"
}

menu_capture() {
    local c
    c=$(pick "capture" "󱄺   Copy text from the screen" "󰩭   Screenshot a region" "󰹑   Screenshot the screen" "󰑋   Record the screen" \
        "󰍬   Record with sound" "󰩭   Record a region" "󰐥   Stop recording") || return
    case "$c" in
        *"Copy text"*) sleep 0.2; "$A" capture text ;;
        *"Screenshot a region"*) sleep 0.2; "$A" capture region ;;
        *"Screenshot the screen"*) sleep 0.3; "$A" capture shot ;;
        *"with sound"*) "$A" capture record-sound ;;
        *"Record a region"*) "$A" capture record-region ;;
        *"Record the screen"* | *Stop*) "$A" capture record ;;
    esac
}

menu_panels() {
    local c
    c=$(pick "panel" "󰘮   Quick settings	control" "󰖩   Network	network" "󰂯   Bluetooth	bluetooth" "󰕾   Sound	sound" \
        "󰃭   Calendar	calendar" "󰐎   Now playing	media" "󰐥   Power	power" "󰚰   Updates	updates") || return
    [ -n "$c" ] && "$A" panel "${c##*$'\t'}"
}

menu_settings() {
    local c pages=(
        "󰖩   Wi-Fi	wifi" "󰂯   Bluetooth	bluetooth" "󰕾   Sound	sound" "󰍹   Display	display"
        "󰌌   Keyboard & mouse	input" "󰌌   Keyboard shortcuts	shortcuts" "󰖔   Night light	nightlight"
        "󰏘   Rices & modes	rices" "󰋩   Wallpaper	wallpaper" "󰕮   Bar & desktop	bar"
        "󰂚   Notifications	notifications" "󰚰   Updates	updates" "󱓞   Startup apps	startup"
        "󰋊   Storage	storage" "󰥔   Date & time	time" "󰌾   Lock & power	power"
        "󰀻   Default apps	apps" "󰋼   About	about")
    c=$(pick "settings" "${pages[@]}") || return
    [ -n "$c" ] && "$A" settings "${c##*$'\t'}"
}

menu_keys() {
    python3 "$ARCHONATE_PY" keybinds | python3 -c '
import json, sys
for b in json.load(sys.stdin):
    print(f"{b[\"label\"]:<34}  " + "  or  ".join(b["keys"]))' |
        fuzzel --dmenu ${cfg:+--config "$cfg"} --prompt "keys  " --width 70 --lines 16 --no-sort >/dev/null 2>&1
}

menu_update() {
    local c
    c=$(pick "update" "󰚰   Update now (snapshot first)" "󰚰   What's waiting" "󰋚   Snapshots") || return
    case "$c" in
        *"Update now"*) "$A" update ;;
        *waiting*) "$A" panel updates ;;
        *Snapshots*) kitty --title Snapshots --hold "$A" snapshot list ;;
    esac
}

menu_power() {
    local c
    c=$(pick "power" "󰙴   Screensaver" "󰌾   Lock" "󰍃   Log out" "󰒲   Sleep" "󰜉   Restart" "󰐥   Shut down") || return
    case "$c" in
        *Screensaver*) sleep 0.3; "$A" screensaver ;;
        *Lock*) "$A" lock ;;
        *"Log out"*) "$A" power logout ;;
        *Sleep*) "$A" power suspend ;;
        *Restart*) "$A" power reboot ;;
        *"Shut down"*) "$A" power shutdown ;;
    esac
}

menu_main() {
    local c
    local first="󰏘   Rice   ($rice)"
    solo && first="󰏘   Style   ($("$ARCHONATE_DIR/cmd/style-current"))"
    c=$(pick "archonate" \
        "$first" \
        "󰘮   Mode   ($(current_mode))" \
        "󰋩   Wallpaper" \
        "󰔡   Switches" \
        "󰕮   Quick panels" \
        "󰄀   Capture" \
        "󰒃   Security" \
        "󰒓   Settings" \
        "󰌌   Keyboard shortcuts" \
        "󰚰   Update" \
        "󰇚   Install" \
        "󰆴   Remove" \
        "󰱱   Emoji" \
        "󰐥   Power") || return
    case "$c" in
        *Rice*|*Style*) menu_rice ;;
        *Mode*) menu_mode ;;
        *Security*) "$A" security ;;
        *Wallpaper*) menu_wallpaper ;;
        *Switches*) menu_toggles ;;
        *panels*) menu_panels ;;
        *Capture*) menu_capture ;;
        *Settings*) menu_settings ;;
        *shortcuts*) menu_keys ;;
        *Update*) menu_update ;;
        *Install*) "$ARCHONATE_DIR/pkg.sh" menu-install ;;
        *Remove*) "$ARCHONATE_DIR/pkg.sh" menu-remove ;;
        *Emoji*) "$A" emoji ;;
        *Power*) menu_power ;;
    esac
}

# A second press closes it
pkill -x fuzzel && exit 0

case "${1:-}" in
    "") menu_main ;;
    rice | theme) menu_rice ;;
    style | styles) menu_style ;;
    mode) menu_mode ;;
    wallpaper) menu_wallpaper ;;
    toggles | switches) menu_toggles ;;
    capture) menu_capture ;;
    panels) menu_panels ;;
    settings) menu_settings ;;
    keys | keybindings) menu_keys ;;
    update) menu_update ;;
    power) menu_power ;;
    install) "$ARCHONATE_DIR/pkg.sh" menu-install ;;
    remove) "$ARCHONATE_DIR/pkg.sh" menu-remove ;;
    *) echo "unknown menu '$1'" >&2; exit 1 ;;
esac
