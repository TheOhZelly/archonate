#!/usr/bin/env bash
# Call this system "Archonate Linux" (what fastfetch, Settings > About, the
# TTY login and other apps show), and keep it that way across updates.
#
#   sudo ~/.config/hypr/lib/setup-branding.sh          # apply + install the hook
#   sudo ~/.config/hypr/lib/setup-branding.sh --undo   # back to CachyOS
#
# Only the display names change. ID=cachyos and ID_LIKE=arch stay, because
# CachyOS's tools, its kernel manager, hardware detection and plenty of apps
# check them to know what system this is.
#
# The boot menu keeps its "CachyOS" entry name: limine.conf is checksummed into
# the Secure Boot-enrolled loader, so it isn't renamed. Limine's tools find
# that entry by PRETTY_NAME unless TARGET_OS_NAME is set in /etc/default/limine,
# so this pins TARGET_OS_NAME to the entry's real name first.
#
# CachyOS rewrites /etc/os-release and /etc/lsb-release whenever `filesystem`
# or `lsb-release` update (cachyos-hooks); the pacman hook installed here runs
# after theirs (zz- sorts last) and puts the Archonate names back.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
grep -q '^ID=cachyos' /etc/os-release || { echo "this renames CachyOS only (it relies on CachyOS's own branding hook); nothing changed" >&2; exit 1; }

script=/usr/local/lib/archonate/branding
hook=/etc/pacman.d/hooks/zz-archonate-branding.hook

limine_default=/etc/default/limine
marker="# archonate: limine finds its boot entry by this name (setup-branding.sh)"

if [ "${1:-}" = --undo ]; then
    rm -f "$hook" "$script"
    [ -f "$limine_default" ] && sed -i "/^$marker\$/,+1d" "$limine_default"
    /usr/share/libalpm/scripts/cachyos-branding all 2>/dev/null ||
        /usr/share/libalpm/scripts/cachyos-branding
    sed -i 's|Archonate Linux|CachyOS Linux|g' /etc/issue 2>/dev/null || true
    systemctl try-restart limine-snapper-sync.service 2>/dev/null || true
    echo "back to CachyOS branding; hook removed"
    exit 0
fi

# Pin limine's target OS name to the boot entry that exists, before renaming
if [ -f "$limine_default" ] && ! grep -q '^TARGET_OS_NAME=' "$limine_default"; then
    entry=CachyOS
    conf=/boot/limine.conf
    [ -r "$conf" ] && ! grep -qE "^/\+?CachyOS\b" "$conf" &&
        entry=$(grep -m1 -E '^/\+?[A-Za-z]' "$conf" | sed -E 's|^/\+?||')
    printf '\n%s\nTARGET_OS_NAME="%s"\n' "$marker" "$entry" >>"$limine_default"
    echo "limine: TARGET_OS_NAME=\"$entry\" (your boot menu entry)"
fi

install -d /usr/local/lib/archonate /etc/pacman.d/hooks
cat >"$script" <<'EOF'
#!/usr/bin/env bash
# Archonate Linux branding (from ~/.config/hypr/lib/setup-branding.sh)
sed -i /etc/os-release \
    -e 's|^NAME=.*$|NAME="Archonate Linux"|' \
    -e 's|^PRETTY_NAME=.*$|PRETTY_NAME="Archonate"|' \
    -e 's|^ANSI_COLOR=.*$|ANSI_COLOR="38;2;143;154;90"|' \
    -e 's|^HOME_URL=.*$|HOME_URL="https://github.com/TheOhZelly/archonate"|'
grep -q '^VARIANT=' /etc/os-release || echo 'VARIANT="CachyOS based"' >>/etc/os-release
sed -i /etc/lsb-release -e 's|^DISTRIB_DESCRIPTION=.*$|DISTRIB_DESCRIPTION="Archonate"|'
sed -i 's|CachyOS Linux|Archonate Linux|g; s|Arch Linux|Archonate Linux|g' /etc/issue 2>/dev/null || true
EOF
chmod 755 "$script"

cat >"$hook" <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = filesystem
Target = lsb-release
Target = cachyos-hooks

[Action]
Description = Keeping the Archonate Linux name...
When = PostTransaction
Exec = $script
EOF

"$script"
echo "This is now Archonate Linux:"
grep -E '^(NAME|PRETTY_NAME|ID|ID_LIKE|VARIANT)=' /etc/os-release | sed 's/^/  /'
systemctl try-restart limine-snapper-sync.service 2>/dev/null || true
echo "Hook: $hook (undo: sudo $0 --undo)"
