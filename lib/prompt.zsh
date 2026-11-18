# Archonate's prompt, coloured by the active style. lib/desktop.py writes
# ~/.local/state/hypr-rice/p10k.zsh ($ARCHONATE_PROMPT, the style's colours);
# open shells pick up a style change at their next prompt. The theme is
# lib/zsh/prompt-theme.zsh; to keep a p10k config of your own instead, set
# ARCHONATE_PROMPT_THEME=~/.p10k.zsh before this is sourced.
zmodload -F zsh/stat b:zstat 2>/dev/null
typeset -g _hypr_rice_p10k=~/.local/state/hypr-rice/p10k.zsh _hypr_rice_p10k_seen=-1
_hypr_rice_prompt() {
    local -a m=(0)
    [[ -e $_hypr_rice_p10k ]] && zstat -A m +mtime -- $_hypr_rice_p10k
    [[ $m[1] == $_hypr_rice_p10k_seen ]] && return
    local first=$(( _hypr_rice_p10k_seen == -1 ))
    _hypr_rice_p10k_seen=$m[1]
    unset ARCHONATE_PROMPT
    [[ -r $_hypr_rice_p10k ]] && source $_hypr_rice_p10k
    local theme=${ARCHONATE_PROMPT_THEME:-$HOME/.config/hypr/lib/zsh/prompt-theme.zsh}
    [[ -r $theme ]] && source $theme
    _archonate_line_colours
    (( first )) || { (( $+functions[p10k] )) && p10k reload; }
}
# the command line's own colours: suggestions dim, commands and strings in the style
_archonate_line_colours() {
    local -A c=(text '#c8ccce' dim '#656c71' accent '#8fa4b2' secondary '#b3a68c' tertiary '#7f948a' error '#c2756e')
    (( ${+ARCHONATE_PROMPT} )) && c+=("${(@kv)ARCHONATE_PROMPT}")
    typeset -g ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=$c[dim]"
    typeset -gA ZSH_HIGHLIGHT_STYLES
    ZSH_HIGHLIGHT_STYLES+=(
        command "fg=$c[accent]" builtin "fg=$c[accent]" alias "fg=$c[accent]" function "fg=$c[accent]"
        precommand "fg=$c[accent],underline" suffix-alias "fg=$c[accent]"
        unknown-token "fg=$c[error]" reserved-word "fg=$c[secondary]"
        single-quoted-argument "fg=$c[secondary]" double-quoted-argument "fg=$c[secondary]"
        dollar-quoted-argument "fg=$c[secondary]" back-quoted-argument "fg=$c[tertiary]"
        single-hyphen-option "fg=$c[tertiary]" double-hyphen-option "fg=$c[tertiary]"
        path "fg=$c[text],underline" globbing "fg=$c[tertiary]" history-expansion "fg=$c[tertiary]"
        comment "fg=$c[dim]" commandseparator "fg=$c[dim]" redirection "fg=$c[dim]"
    )
}
_hypr_rice_prompt
autoload -Uz add-zsh-hook && add-zsh-hook precmd _hypr_rice_prompt
