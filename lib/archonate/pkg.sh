#!/usr/bin/env bash
# Archonate install / remove, like omarchy's menus.
#   pkg.sh menu-install                  sections + search, in the rice's fuzzel
#   pkg.sh menu-remove
#   pkg.sh section <Section>             a curated list (● = already installed)
#   pkg.sh search repo|aur|installed     fzf over packages, live descriptions
#   pkg.sh run install|remove <pkgs...> [--after <cmd>]   (in a terminal)
# The curated lists live in catalog.tsv; paru installs from repos or the AUR.
. "$ARCHONATE_DIR/common.sh"
CAT="$ARCHONATE_DIR/catalog.tsv"
SELF="$ARCHONATE_DIR/pkg.sh"
cfg="$HYPR_DIR/rices/$(current_rice)/fuzzel.ini"; [ -f "$cfg" ] || cfg=""

pick() { # prompt lines...
    local p=$1; shift
    local n=$#; [ "$n" -gt 16 ] && n=16
    printf '%s\n' "$@" | fuzzel --dmenu ${cfg:+--config "$cfg"} --prompt "$p  " --lines "$n" --width 40 --no-sort --with-nth=1 2>/dev/null
}

# A floating terminal (window rule: class archonate-term)
term() { # title, then the command
    local title=$1; shift
    kitty --class archonate-term --title "$title" -o confirm_os_window_close=0 "$@" &
    disown
}

installed() { pacman -Q "$@" >/dev/null 2>&1; }

sections() { grep -v '^#' "$CAT" | cut -f1 | awk '!s[$0]++'; }

icon() {
    case "$1" in
        Browser) printf "󰖟" ;;
        Editor) printf "󰅩" ;;
        Terminal) printf "󰆍" ;;
        Development) printf "󰗀" ;;
        Gaming) printf "󰊗" ;;
        AI) printf "󰚩" ;;
        Apps) printf "󰀻" ;;
        Font) printf "󰛖" ;;
        *) printf " " ;;
    esac
}

section() { # Section [remove]
    local sec=$1 mode=${2:-install} lines=() label pkgs after c
    while IFS=$'\t' read -r s label pkgs after; do
        [ "$s" = "$sec" ] || continue
        if installed $pkgs; then
            lines+=("● $label	$pkgs	$after")
        elif [ "$mode" = install ]; then
            lines+=("  $label	$pkgs	$after")
        fi
    done < <(grep -v '^#' "$CAT")
    [ ${#lines[@]} -gt 0 ] || { notify "Nothing to remove" "No $sec apps from the list are installed"; return; }
    c=$(pick "$( [ "$mode" = install ] && echo install || echo remove) ${sec,,}" "${lines[@]}") || return
    [ -n "$c" ] || return
    IFS=$'\t' read -r label pkgs after <<<"$c"
    label=${label#??}
    if [ "$mode" = install ]; then
        installed $pkgs && { notify "$label" "Already installed"; return; }
        term "Install $label" "$SELF" run install $pkgs ${after:+--after "$after"}
    else
        term "Remove $label" "$SELF" run remove $pkgs
    fi
}

search() { # repo | aur | installed
    local kind=$1 list preview act
    case "$kind" in
        repo) list="pacman -Slq"; preview="pacman -Sii {1}"; act=install ;;
        aur) [ -n "$AUR_HELPER" ] || { echo "no AUR helper (paru or yay) is installed" >&2; exit 1; }
             list="$AUR_HELPER -Slq --aur"; preview="$AUR_HELPER -Si --aur {1}"; act=install ;;
        installed) list="pacman -Qeq"; preview="pacman -Qi {1}"; act=remove ;;
    esac
    term "Archonate · $act $kind" bash -c "
        sel=\$($list 2>/dev/null | fzf --multi --prompt '$act › ' \
            --header 'type to search · tab marks several · enter $act' \
            --preview '$preview' --preview-window 'down:60%:wrap' \
            --color 'pointer:green,marker:green')
        [ -n \"\$sel\" ] && exec '$SELF' run $act \$sel"
}

run() { # install|remove pkgs... [--after cmd]
    # Started from the menu or a key: no terminal for sudo, so open one
    if [ ! -t 0 ]; then
        term "Archonate · $1" "$SELF" run "$@"
        return
    fi
    local act=$1; shift
    local pkgs=() after=""
    while [ $# -gt 0 ]; do
        if [ "$1" = --after ]; then after=$2; shift 2; else pkgs+=("$1"); shift; fi
    done
    "$BIN/archonate" logo; echo
    echo -e "\e[1m${act^}: ${pkgs[*]}\e[0m\n"
    local ok=0
    if [ "$act" = install ]; then
        ${AUR_HELPER:-sudo pacman} -S --needed "${pkgs[@]}" || ok=$?
        if [ $ok -eq 0 ] && [ -n "$after" ]; then
            echo -e "\n\e[1mSetting up…\e[0m"
            sudo SUDO_USER="$USER" bash -c "$after" || ok=$?
        fi
    else
        ${AUR_HELPER:-sudo pacman} -Rns "${pkgs[@]}" || ok=$?
    fi
    echo
    if [ $ok -eq 0 ]; then
        echo -e "\e[32mDone.\e[0m"
        notify "${act^}ed" "${pkgs[*]}"
    else
        echo -e "\e[31mThat didn't finish (exit $ok). Nothing was half-applied by pacman.\e[0m"
    fi
    read -rsn1 -p "Press any key to close."
}

menu() { # install|remove
    local mode=$1 c secs=() s
    while read -r s; do secs+=("$(icon "$s")   $s"); done < <(sections)
    if [ "$mode" = install ]; then
        c=$(pick "install" "󰍉   Search packages (repos)" "󰏖   Search the AUR" "${secs[@]}") || return
        case "$c" in
            *"(repos)"*) search repo ;;
            *AUR*) search aur ;;
            ?*) section "${c##* }" install ;;
        esac
    else
        c=$(pick "remove" "󰍉   Search installed packages" "${secs[@]}") || return
        case "$c" in
            *"installed packages"*) search installed ;;
            ?*) section "${c##* }" remove ;;
        esac
    fi
}

case "${1:-}" in
    menu-install) menu install ;;
    menu-remove) menu remove ;;
    section) section "$2" "${3:-install}" ;;
    search) search "$2" ;;
    run) shift; run "$@" ;;
    *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
