# Archonate's zsh: history, completion, keys, plugins and the prompt.
# ~/.zshrc sources this (install.sh adds the line); put your own lines after it.
# Anything another framework (oh-my-zsh, a distro's zsh config) already loaded
# is left alone, so it's safe to source on top of one.

# ---- history -----------------------------------------------------------------
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=50000
SAVEHIST=50000
setopt extended_history hist_expire_dups_first hist_ignore_dups hist_ignore_space \
    hist_verify inc_append_history share_history

# ---- behaviour -----------------------------------------------------------------
setopt auto_cd auto_pushd pushd_ignore_dups pushd_silent interactive_comments \
    no_beep glob_dots extended_glob
WORDCHARS=${WORDCHARS//\/}          # ctrl+w / alt+backspace stop at /

# ---- completion -------------------------------------------------------------------
[[ -d /usr/share/zsh/site-functions ]] && fpath=(/usr/share/zsh/site-functions $fpath)
if ! (( $+functions[compdef] )); then
    autoload -Uz compinit
    # one full check a day, the cached dump otherwise (fast new terminals)
    local _zc=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump
    mkdir -p ${_zc:h}
    if [[ -n $_zc(#qN.mh+24) || ! -e $_zc ]]; then compinit -d $_zc; else compinit -C -d $_zc; fi
    unset _zc
fi
zmodload zsh/complist 2>/dev/null
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{8}── %d ──%f'
zstyle ':completion:*:warnings' format '%F{8}nothing matches%f'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# ---- keys -------------------------------------------------------------------------
bindkey -e
bindkey '^[[1;5C' forward-word       # ctrl+right
bindkey '^[[1;5D' backward-word      # ctrl+left
bindkey '^[[H' beginning-of-line     # home
bindkey '^[[F' end-of-line           # end
bindkey '^[[3~' delete-char          # delete
bindkey '^[[3;5~' kill-word          # ctrl+delete
bindkey '^H' backward-kill-word      # ctrl+backspace
bindkey '^[[Z' reverse-menu-complete # shift+tab
autoload -Uz edit-command-line && zle -N edit-command-line
bindkey '^X^E' edit-command-line     # the line in $EDITOR

# ---- plugins (Arch packages; each only if nothing loaded it already) ------------------
_archonate_plug=/usr/share/zsh/plugins
if ! (( $+functions[_zsh_autosuggest_start] )) && [[ -r $_archonate_plug/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=40
    source $_archonate_plug/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
if ! (( $+functions[history-substring-search-up] )) && [[ -r $_archonate_plug/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source $_archonate_plug/zsh-history-substring-search/zsh-history-substring-search.zsh
fi
if (( $+functions[history-substring-search-up] )); then
    # up/down search history for what's typed so far
    bindkey '^[[A' history-substring-search-up;   bindkey '^[OA' history-substring-search-up
    bindkey '^[[B' history-substring-search-down; bindkey '^[OB' history-substring-search-down
    HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
fi
# fzf: ctrl+r history, ctrl+t files, alt+c directories
if (( $+commands[fzf] )) && ! (( $+widgets[fzf-history-widget] )); then
    source <(fzf --zsh) 2>/dev/null
fi

# ---- tools ---------------------------------------------------------------------------
if (( $+commands[eza] )); then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -l --icons=auto --group-directories-first --git --time-style=relative'
    alias la='eza -la --icons=auto --group-directories-first --git --time-style=relative'
    alias lt='eza --tree --level=2 --icons=auto'
else
    alias ls='ls --color=auto'
    alias ll='ls -lh --color=auto'
    alias la='ls -lah --color=auto'
fi
alias grep='grep --color=auto'
alias ip='ip -color=auto'
alias diff='diff --color=auto'
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# ---- the prompt ------------------------------------------------------------------------
# powerlevel10k with Archonate's theme (lib/zsh/prompt-theme.zsh), coloured by the style
if ! (( $+functions[p10k] )) && [[ -r /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme ]]; then
    source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
fi
[[ -r ~/.config/hypr/lib/prompt.zsh ]] && source ~/.config/hypr/lib/prompt.zsh

# syntax highlighting goes last: it wraps every widget defined before it
if ! (( $+ZSH_HIGHLIGHT_VERSION )) && [[ -r $_archonate_plug/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
    source $_archonate_plug/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
unset _archonate_plug
