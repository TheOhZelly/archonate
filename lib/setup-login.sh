#!/usr/bin/env bash
# The ARCHONATE login screen (SDDM). Run with sudo, in this order:
#   sudo ~/.config/hypr/lib/setup-login.sh install   # copy the theme in; changes nothing else
#   sudo ~/.config/hypr/lib/setup-login.sh switch    # use SDDM instead of Plasma Login (next boot)
#   sudo ~/.config/hypr/lib/setup-login.sh undo      # back to Plasma Login, exactly as before
# Preview without root:  archonate login preview
# Needs:  sudo pacman -S sddm
set -euo pipefail

user=${SUDO_USER:?run this with sudo}
src="/home/$user/.config/hypr/login/archonate"
dst=/usr/share/sddm/themes/archonate
conf=/etc/sddm.conf.d/10-archonate.conf

case "${1:-}" in
    install)
        command -v sddm >/dev/null || { echo "install SDDM first: sudo pacman -S sddm" >&2; exit 1; }
        rm -rf "$dst"
        mkdir -p "$dst"
        cp -L "$src"/*.qml "$src"/*.js "$src"/metadata.desktop "$src"/theme.conf "$src"/logo.txt "$dst"/
        [ -f "$src/preview.png" ] && cp "$src/preview.png" "$dst/"
        # Colours/font follow your rice: written by hypr-rice into the folder
        # setup-root.sh made (owned by you, readable by the greeter)
        install -d -o "$user" -m 755 /var/lib/hypr-rice-login
        ln -sfn /var/lib/hypr-rice-login/theme.conf "$dst/theme.conf.user"
        mkdir -p /etc/sddm.conf.d
        cat >"$conf" <<CONF
# ARCHONATE login screen (from ~/.config/hypr/lib/setup-login.sh)
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1

[Theme]
Current=archonate
CONF
        echo "theme installed at $dst; config $conf"
        echo "next: sudo $0 switch   (then reboot)"
        ;;
    switch)
        [ -d "$dst" ] || { echo "run '$0 install' first" >&2; exit 1; }
        systemctl disable plasmalogin.service
        systemctl enable sddm.service
        echo "SDDM will greet you from the next boot. Back out any time: sudo $0 undo"
        ;;
    undo)
        systemctl disable sddm.service 2>/dev/null || true
        systemctl enable plasmalogin.service
        rm -f "$conf"
        echo "Plasma Login restored from the next boot (the theme files stay in $dst)"
        ;;
    *)
        sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
