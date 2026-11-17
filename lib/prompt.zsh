# hypr-rice: prompt colours follow the active rice. lib/desktop.py writes
# ~/.local/state/hypr-rice/p10k.zsh (removed when a rice has no palette); open shells pick up
# a change at their next prompt. Sourced from ~/.zshrc (install.sh adds the line).
zmodload -F zsh/stat b:zstat 2>/dev/null
typeset -g _hypr_rice_p10k=~/.local/state/hypr-rice/p10k.zsh _hypr_rice_p10k_seen=-1
_hypr_rice_prompt() {
    local -a m=(0)
    [[ -e $_hypr_rice_p10k ]] && zstat -A m +mtime -- $_hypr_rice_p10k
    [[ $m[1] == $_hypr_rice_p10k_seen ]] && return
    local first=$(( _hypr_rice_p10k_seen == -1 ))
    _hypr_rice_p10k_seen=$m[1]
    (( first && m[1] == 0 )) && return
    [[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh
    [[ -r $_hypr_rice_p10k ]] && source $_hypr_rice_p10k
    (( first )) || p10k reload
}
_hypr_rice_prompt
autoload -Uz add-zsh-hook && add-zsh-hook precmd _hypr_rice_prompt

