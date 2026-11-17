# Coding agents, for the `archonate agent` commands. Sourced, not run.
#
#   id|command|name|how it takes a starting prompt
#     arg     the prompt is the first argument          (claude "...")
#     flag:X  the prompt follows flag X                  (opencode --prompt "...")
#     -       no way known: it opens, and the prompt goes to the clipboard
AGENTS=(
    "claude|claude|Claude Code|arg"
    "codex|codex|Codex|arg"
    "opencode|opencode|OpenCode|flag:--prompt"
    "gemini|gemini|Gemini CLI|flag:-i"
    "crush|crush|Crush|-"
    "copilot|copilot|GitHub Copilot CLI|-"
    "amp|amp|Amp|-"
    "kimi|kimi|Kimi Code|-"
    "pi|pi|Pi|-"
    "cursor|cursor-agent|Cursor CLI|-"
    "qwen|qwen|Qwen Code|-"
)
AGENT_FILE="$HOME/.config/archonate/agent" # your pick: one id

agent_field() { # id field(1-4)
    local a
    for a in "${AGENTS[@]}"; do
        [ "${a%%|*}" = "$1" ] && { cut -d'|' -f"$2" <<<"$a"; return 0; }
    done
    return 1
}

agents_installed() { # ids of the agents on this machine, in AGENTS order
    local a
    for a in "${AGENTS[@]}"; do
        command -v "$(cut -d'|' -f2 <<<"$a")" >/dev/null 2>&1 && echo "${a%%|*}"
    done
}

agent_default() { # your pick if it's still installed, else the first installed
    local id=""
    [ -f "$AGENT_FILE" ] && read -r id <"$AGENT_FILE"
    if [ -n "$id" ] && command -v "$(agent_field "$id" 2)" >/dev/null 2>&1; then
        echo "$id"
    else
        agents_installed | head -1
    fi
}

# Open agent <id> in a terminal of its own, optionally starting on a prompt
agent_launch() { # id [prompt]
    local id=$1 prompt=${2:-} cmd name how
    cmd=$(agent_field "$id" 2) && name=$(agent_field "$id" 3) && how=$(agent_field "$id" 4) || {
        echo "unknown agent: $id" >&2; return 1; }
    command -v "$cmd" >/dev/null || { echo "$name isn't installed (archonate install ai)" >&2; return 1; }
    local args=("$cmd")
    if [ -n "$prompt" ]; then
        case "$how" in
            arg) args+=("$prompt") ;;
            flag:*) args+=("${how#flag:}" "$prompt") ;;
            *)
                printf '%s' "$prompt" | wl-copy
                notify "$name" "Your question is on the clipboard: paste it in (CTRL+SHIFT+V)." ;;
        esac
    fi
    # From a key or a notification there's no terminal yet: open one
    setsid -f kitty --class archonate-agent --title "$name" --directory "$HOME" "${args[@]}" >/dev/null 2>&1
}
