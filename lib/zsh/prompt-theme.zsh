# Archonate's prompt: a powerlevel10k theme of its own.
#
#   ╭─ Λ  ~/.config/hypr   master ✔ ·············· took 3s · 19:42
#   ╰─❯
#
# Two lines in a thin frame, the path in the style's accent, git beside it, and
# on the right only what matters (a failed status, a slow command, jobs, ssh or
# root, the time). Finished commands collapse to a bare ❯ so the scrollback
# stays clean. Colours come from the active style (lib/desktop.py writes
# ~/.local/state/hypr-rice/p10k.zsh as $ARCHONATE_PROMPT); without one, the
# built-in archonate style's. Sourced by lib/prompt.zsh; re-sourced on a style
# change.

# Start from nothing: whatever another p10k config set doesn't leak in
unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

() {
    emulate -L zsh -o extended_glob
    local -A c=(
        frame '#2d3135' text '#c8ccce' dim '#656c71' accent '#8fa4b2'
        secondary '#b3a68c' tertiary '#7f948a' error '#c2756e'
    )
    (( ${+ARCHONATE_PROMPT} )) && c+=("${(@kv)ARCHONATE_PROMPT}")

    # ---- layout -------------------------------------------------------------
    typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
        os_icon dir vcs
        newline
        prompt_char
    )
    typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
        status command_execution_time background_jobs
        direnv virtualenv nvm context time
        newline
    )
    typeset -g POWERLEVEL9K_MODE=nerdfont-v3
    typeset -g POWERLEVEL9K_ICON_PADDING=none
    typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
    typeset -g POWERLEVEL9K_BACKGROUND=                      # no blocks: text on the terminal
    typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{LEFT,RIGHT}_WHITESPACE=
    # no backgrounds, so p10k joins segments with the sub-segment separator
    typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='  '
    typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR="%F{$c[frame]} · "
    typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SEGMENT_SEPARATOR=
    typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR='  '
    typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=
    typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=' '
    typeset -g POWERLEVEL9K_VISUAL_IDENTIFIER_EXPANSION='${P9K_VISUAL_IDENTIFIER}'

    # the frame
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="%F{$c[frame]}╭─ "
    typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX="%F{$c[frame]}├─ "
    typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="%F{$c[frame]}╰─"
    typeset -g POWERLEVEL9K_MULTILINE_{FIRST,NEWLINE,LAST}_PROMPT_SUFFIX=
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR='·'
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND=$c[frame]
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_BACKGROUND=
    typeset -g POWERLEVEL9K_EMPTY_LINE_LEFT_PROMPT_FIRST_SEGMENT_END_SYMBOL='%{%}'

    # ---- Λ: the Archonate mark ------------------------------------------------
    typeset -g POWERLEVEL9K_OS_ICON_CONTENT_EXPANSION='%BΛ%b'
    typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=$c[accent]

    # ---- the prompt character -------------------------------------------------
    typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=$c[accent]
    typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=$c[error]
    typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='❮'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='▶'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true
    typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=
    typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=

    # ---- directory ------------------------------------------------------------
    typeset -g POWERLEVEL9K_DIR_FOREGROUND=$c[accent]
    typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=$c[dim]
    typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=$c[text]
    typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true
    typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
    typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
    typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
    typeset -g POWERLEVEL9K_SHORTEN_FOLDER_MARKER='(.git|.hg|package.json|Cargo.toml|go.mod|pyproject.toml)'
    typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=80
    typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=40
    typeset -g POWERLEVEL9K_DIR_HYPERLINK=true
    typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=v3
    typeset -g POWERLEVEL9K_LOCK_ICON='󰌾'
    typeset -g POWERLEVEL9K_DIR_VISUAL_IDENTIFIER_EXPANSION=

    # ---- git --------------------------------------------------------------------
    typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=' '
    typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'
    typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_EXPANSION=
    typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'
    typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)
    typeset -g POWERLEVEL9K_VCS_{CLEAN,UNTRACKED,MODIFIED}_FOREGROUND=$c[secondary]
    typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=$c[dim]
    typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION='${$((my_git_formatter(1)))+${my_git_format}}'
    typeset -g POWERLEVEL9K_VCS_LOADING_CONTENT_EXPANSION='${$((my_git_formatter(0)))+${my_git_format}}'
    typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=-1
    typeset -g POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING=true  # my_git_formatter draws it
    typeset -g _archonate_git=(${c[secondary]} ${c[tertiary]} ${c[error]} ${c[dim]})

    # ---- right side ---------------------------------------------------------------
    typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
    typeset -g POWERLEVEL9K_STATUS_OK=false
    typeset -g POWERLEVEL9K_STATUS_OK_PIPE=false
    typeset -g POWERLEVEL9K_STATUS_{ERROR,ERROR_SIGNAL,ERROR_PIPE}=true
    typeset -g POWERLEVEL9K_STATUS_{ERROR,ERROR_SIGNAL,ERROR_PIPE}_FOREGROUND=$c[error]
    typeset -g POWERLEVEL9K_STATUS_{ERROR,ERROR_SIGNAL,ERROR_PIPE}_VISUAL_IDENTIFIER_EXPANSION=
    typeset -g POWERLEVEL9K_STATUS_{ERROR,ERROR_SIGNAL,ERROR_PIPE}_PREFIX='✗ '
    typeset -g POWERLEVEL9K_STATUS_VERBOSE_SIGNAME=false

    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s'
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=$c[tertiary]
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_VISUAL_IDENTIFIER_EXPANSION=
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PREFIX="%F{$c[dim]}took "

    typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=$c[secondary]
    typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=true
    typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VISUAL_IDENTIFIER_EXPANSION=
    typeset -g POWERLEVEL9K_BACKGROUND_JOBS_PREFIX='⚙ '

    typeset -g POWERLEVEL9K_{DIRENV,VIRTUALENV,NVM}_FOREGROUND=$c[tertiary]
    typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false
    typeset -g POWERLEVEL9K_VIRTUALENV_{LEFT,RIGHT}_DELIMITER=

    # user@host only over ssh or as root, root in the error colour
    typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND=$c[dim]
    typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=$c[error]
    typeset -g POWERLEVEL9K_CONTEXT_{REMOTE,REMOTE_SUDO}_FOREGROUND=$c[secondary]
    typeset -g POWERLEVEL9K_CONTEXT_ROOT_TEMPLATE='%B%n%b@%m'
    typeset -g POWERLEVEL9K_CONTEXT_{REMOTE,REMOTE_SUDO}_TEMPLATE='%n@%m'
    typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO}_{CONTENT,VISUAL_IDENTIFIER}_EXPANSION=

    typeset -g POWERLEVEL9K_TIME_FOREGROUND=$c[dim]
    typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
    typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=false
    typeset -g POWERLEVEL9K_TIME_VISUAL_IDENTIFIER_EXPANSION=

    # ---- behaviour ------------------------------------------------------------------
    typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always            # old prompts collapse to ❯
    typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
    typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true  # this is the configuration
    typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true
}

# git: branch, then ahead/behind, then what's staged/changed/untracked, each in
# its own colour. Called by p10k with 1 (fresh status) or 0 (still loading).
function my_git_formatter() {
    emulate -L zsh
    if [[ -n $P9K_CONTENT ]]; then typeset -g my_git_format=$P9K_CONTENT; return; fi
    local ok=${_archonate_git[1]} mod=${_archonate_git[2]} bad=${_archonate_git[3]} dim=${_archonate_git[4]}
    (( $1 )) || { ok=$dim mod=$dim bad=$dim; }
    local b="%F{$ok} "
    if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
        local br=$VCS_STATUS_LOCAL_BRANCH
        (( $#br > 32 )) && br="${br[1,12]}…${br[-12,-1]}"
        b+="${br//\%/%%}"
    elif [[ -n $VCS_STATUS_TAG ]]; then b+="#${VCS_STATUS_TAG//\%/%%}"
    else b+="@${VCS_STATUS_COMMIT[1,8]}"; fi
    (( VCS_STATUS_COMMITS_BEHIND )) && b+=" %F{$mod}⇣$VCS_STATUS_COMMITS_BEHIND"
    (( VCS_STATUS_COMMITS_AHEAD )) && b+=" %F{$mod}⇡$VCS_STATUS_COMMITS_AHEAD"
    (( VCS_STATUS_STASHES )) && b+=" %F{$dim}*$VCS_STATUS_STASHES"
    [[ -n $VCS_STATUS_ACTION ]] && b+=" %F{$bad}$VCS_STATUS_ACTION"
    (( VCS_STATUS_NUM_CONFLICTED )) && b+=" %F{$bad}~$VCS_STATUS_NUM_CONFLICTED"
    (( VCS_STATUS_NUM_STAGED )) && b+=" %F{$mod}+$VCS_STATUS_NUM_STAGED"
    (( VCS_STATUS_NUM_UNSTAGED )) && b+=" %F{$mod}!$VCS_STATUS_NUM_UNSTAGED"
    (( VCS_STATUS_NUM_UNTRACKED )) && b+=" %F{$dim}?$VCS_STATUS_NUM_UNTRACKED"
    if (( $1 )) && ! (( VCS_STATUS_NUM_STAGED + VCS_STATUS_NUM_UNSTAGED + VCS_STATUS_NUM_UNTRACKED + VCS_STATUS_NUM_CONFLICTED )); then
        b+=" %F{$ok}✔"
    fi
    typeset -g my_git_format=$b
}
functions -M my_git_formatter 2>/dev/null
