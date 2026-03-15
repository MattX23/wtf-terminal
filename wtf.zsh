#!/usr/bin/env zsh
# =============================================================================
# wtf.zsh — Explains the last terminal command's error using Claude AI
#
# Install:
#   echo 'source "/path/to/wtf.zsh"' >> ~/.zshrc
#
# Or one-liner:
#   curl -fsSL https://raw.githubusercontent.com/mattnorthwood/wtf-terminal/main/install.sh | sh
#
# Requires:
#   Path A (default): curl + ANTHROPIC_API_KEY env var
#   Path B (fallback): Claude Code CLI  (claude -p)
#
# MIT License — Copyright (c) 2026
# =============================================================================

# ── State ─────────────────────────────────────────────────────────────────────
typeset -g _wtf_last_cmd=""
typeset -g _wtf_last_exit=0
typeset -g _wtf_stderr_file=""
typeset -g _wtf_saved_stderr_fd=""
typeset -g _wtf_capture_active=0

# ── JSON helper (pure shell, no jq / python required) ─────────────────────────
_wtf_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"      # backslash first — must be before other replacements
    s="${s//\"/\\\"}"      # double quotes
    s="${s//$'\n'/\\n}"    # newlines
    s="${s//$'\r'/\\r}"    # carriage returns
    s="${s//$'\t'/\\t}"    # tabs
    printf '%s' "$s"
}

# ── Hooks ─────────────────────────────────────────────────────────────────────
_wtf_preexec() {
    local cmd="$1"

    # Don't intercept wtf / why themselves
    if [[ "$cmd" == wtf* || "$cmd" == why* ]]; then
        _wtf_capture_active=0
        return
    fi

    _wtf_last_cmd="$cmd"
    _wtf_capture_active=1
    _wtf_stderr_file=$(mktemp "${TMPDIR:-/tmp}/wtf_stderr.XXXXXX")

    # Save current stderr fd, then redirect shell stderr through tee so output
    # still appears on the terminal AND gets written to the temp file.
    exec {_wtf_saved_stderr_fd}>&2 2> >(tee -- "$_wtf_stderr_file" >&${_wtf_saved_stderr_fd})
}

_wtf_precmd() {
    # zsh guarantees $? is the user command's exit code for every precmd hook.
    local exit_code=$?

    if (( _wtf_capture_active )); then
        _wtf_last_exit=$exit_code
        _wtf_capture_active=0
    fi

    # Restore stderr if a redirect was set up
    if [[ -n "$_wtf_saved_stderr_fd" ]]; then
        exec 2>&${_wtf_saved_stderr_fd} {_wtf_saved_stderr_fd}>&-
        _wtf_saved_stderr_fd=""
    fi
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _wtf_preexec
add-zsh-hook precmd  _wtf_precmd

# ── Transport A: Anthropic API (streaming) ────────────────────────────────────
_wtf_via_api() {
    local prompt="$1"
    local escaped
    escaped=$(_wtf_json_escape "$prompt")

    local payload
    printf -v payload \
        '{"model":"claude-haiku-4-5-20251001","max_tokens":512,"stream":true,"messages":[{"role":"user","content":"%s"}]}' \
        "$escaped"

    local line json chunk text c esc i

    curl -sS --no-buffer \
        -H "x-api-key: ${ANTHROPIC_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$payload" \
        "https://api.anthropic.com/v1/messages" \
    | while IFS= read -r line; do

        # SSE lines are prefixed with "data: "
        [[ "$line" != "data: "* ]] && continue
        json="${line#data: }"
        [[ "$json" == "[DONE]" ]] && break

        # Only extract text from content delta events
        [[ "$json" != *'"type":"text_delta"'* ]] && continue

        # Strip prefix up to the text value
        chunk="${json#*\"text\":\"}"

        # Walk the chunk character by character to handle escape sequences and
        # stop at the closing unescaped quote.  Short chunks (~10 chars each)
        # make this fast even in pure shell.
        text=""
        esc=0
        i=0
        while (( i < ${#chunk} )); do
            c="${chunk:$i:1}"
            if (( esc )); then
                case "$c" in
                    n)   text+=$'\n' ;;
                    t)   text+=$'\t' ;;
                    r)   text+=$'\r' ;;
                    '"') text+='"'   ;;
                    '\') text+='\'   ;;
                    *)   text+="\\$c" ;;
                esac
                esc=0
            elif [[ "$c" == '\' ]]; then
                esc=1
            elif [[ "$c" == '"' ]]; then
                break
            else
                text+="$c"
            fi
            (( ++i ))
        done

        printf '%s' "$text"
    done

    printf '\n'
}

# ── Transport B: Claude Code CLI (MCP / Pro fallback) ─────────────────────────
_wtf_via_mcp() {
    local prompt="$1"

    if command -v claude &>/dev/null; then
        claude -p "$prompt" 2>/dev/null
        return $?
    fi

    return 2  # sentinel: claude not found
}

# ── Dispatcher — only this function differs between transports ─────────────────
_wtf_send_to_claude() {
    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        _wtf_via_api "$1"
        return $?
    fi

    _wtf_via_mcp "$1"
    local rc=$?

    if (( rc == 2 )); then
        printf '\e[2mSetup required — wtf needs one of the following:\e[0m\n\n'
        printf '  \e[1m1. Anthropic API key\e[0m  (any Claude plan)\n'
        printf '     export ANTHROPIC_API_KEY="sk-ant-..."\n\n'
        printf '  \e[1m2. Claude Code CLI\e[0m  (Claude Pro subscription, no key needed)\n'
        printf '     npm install -g @anthropic-ai/claude-code\n'
        printf '     claude  \e[2m# log in once\e[0m\n\n'
        return 1
    fi

    return $rc
}

# ── Main command ───────────────────────────────────────────────────────────────
wtf() {
    local verbose=0

    for arg in "$@"; do
        case "$arg" in
            --verbose|-v) verbose=1 ;;
            --help|-h|help)
                printf '\n  \e[1;33m⚡ wtf\e[0m\n\n'
                printf '  Explains the last failed command using Claude AI.\n\n'
                printf '  \e[1mUsage:\e[0m\n'
                printf '    wtf              Explain the last error\n'
                printf '    wtf why          Alias for wtf\n'
                printf '    wtf --verbose    Include history, cwd, and OS info\n'
                printf '    wtf --help       Show this help\n\n'
                printf '  \e[1mTransports (checked in order):\e[0m\n'
                printf '    ANTHROPIC_API_KEY set → streams via Anthropic API\n'
                printf '    claude CLI found      → uses Claude Code (Pro)\n\n'
                return 0
                ;;
        esac
    done

    if [[ -z "$_wtf_last_cmd" ]]; then
        printf '\n  \e[1;33m⚡ wtf\e[0m  \e[2mNo command captured yet — run a command first.\e[0m\n\n'
        return 0
    fi

    if (( _wtf_last_exit == 0 )); then
        printf '\n  \e[1;32m⚡ wtf\e[0m  \e[2mLast command exited cleanly (exit 0) — nothing to explain.\e[0m\n\n'
        return 0
    fi

    # Read captured stderr (cap at 50 lines to keep prompt reasonable)
    local stderr_output=""
    if [[ -f "$_wtf_stderr_file" && -s "$_wtf_stderr_file" ]]; then
        stderr_output=$(tail -50 "$_wtf_stderr_file")
    fi

    # Build prompt ─────────────────────────────────────────────────────────────
    local prompt="A terminal command failed."
    prompt+=" Command: ${_wtf_last_cmd}."
    prompt+=" Exit code: ${_wtf_last_exit}."
    prompt+=" Error output: ${stderr_output:-none captured}."

    if (( verbose )); then
        local hist_ctx
        hist_ctx=$(fc -l -10 2>/dev/null)
        prompt+=" Recent history: ${hist_ctx}."
        prompt+=" Working directory: ${PWD}."
        prompt+=" OS: $(uname -s) $(uname -r)."
    fi

    prompt+=" Explain what went wrong in 2-3 sentences and suggest the most likely fix."
    prompt+=" Be concise and direct, no preamble."

    # Header ───────────────────────────────────────────────────────────────────
    printf '\n  \e[1;33m⚡ wtf\e[0m  \e[2m%s\e[0m  \e[31m(exit %d)\e[0m\n\n' \
        "$_wtf_last_cmd" "$_wtf_last_exit"

    # Response — streamed directly so output appears progressively
    printf '  '
    _wtf_send_to_claude "$prompt" | sed $'s/\n/\n  /g'

    printf '\n'
}

# ── Aliases ────────────────────────────────────────────────────────────────────
# `wtf why` works naturally because wtf ignores unknown positional args.
# `why` is a convenience alias for single-word invocation.
alias why='wtf'
