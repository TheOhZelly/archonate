#!/usr/bin/env bash
# One-time root setup so hypr-rice can theme two system-level things without
# asking for a password on every switch:
#   - Brave's toolbar colour: a managed policy file owned by you
#   - the Plasma Login screen wallpaper: a folder owned by you that the
#     greeter reads its wallpaper from
# Run:  sudo ~/.config/hypr/lib/setup-root.sh        (safe to run again)
# Undo: sudo ~/.config/hypr/lib/setup-root.sh --undo
set -euo pipefail

user=${SUDO_USER:?run this with sudo}
policy=/etc/brave/policies/managed/hypr-rice.json
login_dir=/var/lib/hypr-rice-login
conf=/etc/plasmalogin.conf
marker="# hypr-rice: login wallpaper"

if [ "${1:-}" = --undo ]; then
    rm -f "$policy"
    rm -rf "$login_dir"
    [ -f "$conf.bak-hypr-rice" ] && cp "$conf.bak-hypr-rice" "$conf"
    echo "hypr-rice root setup removed"
    exit 0
fi

# Brave
install -d -m 755 /etc/brave/policies/managed
[ -f "$policy" ] || echo '{}' >"$policy"
chown "$user" "$policy"
chmod 644 "$policy"

# Login wallpaper folder, readable by the greeter
install -d -o "$user" -m 755 "$login_dir"

# Point the greeter at it (keeps everything already in plasmalogin.conf)
if ! grep -qF "$marker" "$conf" 2>/dev/null; then
    [ -f "$conf" ] && [ ! -f "$conf.bak-hypr-rice" ] && cp "$conf" "$conf.bak-hypr-rice"
    cat >>"$conf" <<EOF

$marker
[Greeter]
WallpaperPluginId=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file://$login_dir/wallpaper.jpg
EOF
fi

echo "done: Brave policy $policy, login wallpaper $login_dir (backup: $conf.bak-hypr-rice)"
