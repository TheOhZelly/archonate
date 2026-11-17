# fastfetch with a shine across the rice's logo, for new terminals.
# zsh runs fastfetch itself (so its "shell" line says zsh), prints it, then
# hands the logo to lib/archonate/fetch-shine.py to animate in place.
# ARCHONATE_NO_SHINE=1 for plain fastfetch.
archonate_fetch() {
    local out n
    out=$(fastfetch --pipe false) || { fastfetch; return; }
    print -r -- "$out"
    n=${#out//[^$'\n']/}     # newlines in the output...
    (( n++ ))                 # ...plus the one print added
    python3 -I ~/.config/hypr/lib/archonate/fetch-shine.py --after $n 2>/dev/null
    return 0
}
