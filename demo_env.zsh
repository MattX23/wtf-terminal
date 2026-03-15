#!/usr/bin/env zsh
# Demo environment for vhs recording.
# Simulates wtf behaviour with scripted output — no API key or live commands
# needed, so the gif can be regenerated in any environment.

# ── Colours ────────────────────────────────────────────────────────────────────
_b=$'\e[1m' _d=$'\e[2m' _r=$'\e[0m'
_yel=$'\e[1;33m' _red=$'\e[31m'

# ── Helper: stream text character-by-character like a real API response ────────
_demo_stream() {
    local text="$1" delay="${2:-0.018}"
    local i
    for (( i=0; i < ${#text}; i++ )); do
        printf '%s' "${text:$i:1}"
        sleep "$delay"
    done
    printf '\n'
}

# ── Scene 1: npm install with no package.json ──────────────────────────────────
npm() {
    if [[ "$1" == "install" ]]; then
        printf 'npm error code ENOENT\n'
        printf 'npm error syscall open\n'
        printf 'npm error path /Users/you/project/package.json\n'
        printf 'npm error errno -2\n'
        printf 'npm error enoent Could not read package.json\n'
        return 1
    fi
    command npm "$@"
}

# ── Scene 2: git push to a branch without upstream ────────────────────────────
git() {
    if [[ "$1" == "push" ]]; then
        printf 'error: src refspec my-feature does not match any\n'
        printf 'error: failed to push some refs to '"'"'git@github.com:you/repo.git'"'"'\n'
        return 128
    fi
    command git "$@"
}

# ── wtf and why ────────────────────────────────────────────────────────────────
_wtf_last_cmd=""
_wtf_last_exit=0

wtf() {
    if [[ -z "$_wtf_last_cmd" ]]; then
        printf '\n  %s⚡ wtf%s  %sNo command captured yet — run a command first.%s\n\n' \
            "$_yel" "$_r" "$_d" "$_r"
        return 0
    fi

    printf '\n  %s⚡ wtf%s  %s%s%s  %s(exit %d)%s\n\n' \
        "$_yel" "$_r" \
        "$_d" "$_wtf_last_cmd" "$_r" \
        "$_red" "$_wtf_last_exit" "$_r"

    printf '  '
    case "$_wtf_last_cmd" in
        npm\ install*)
            _demo_stream "There's no package.json in the current directory, so npm has nothing to install. Navigate to your project root with \`cd\`, or run \`npm init\` to create one."
            ;;
        git\ push*)
            _demo_stream "The local branch hasn't been pushed before, so git doesn't know where to send it. Run \`git push -u origin my-feature\` to set the upstream and push in one step."
            ;;
        *)
            _demo_stream "The command exited with a non-zero status. Check the error output above for details."
            ;;
    esac
    printf '\n'
}

alias why='wtf'

# ── Hook shims — update state when a demo command is run ──────────────────────
# In a real session preexec/precmd handle this; here we wrap the demo commands.
npm() {
    _wtf_last_cmd="npm $*"
    command npm "$@"
    _wtf_last_exit=$?
    # Replicate error output since we overrode npm above
    if [[ "$1" == "install" ]]; then
        printf 'npm error code ENOENT\n'
        printf 'npm error syscall open\n'
        printf 'npm error path /Users/you/project/package.json\n'
        printf 'npm error errno -2\n'
        printf 'npm error enoent Could not read package.json\n'
        _wtf_last_exit=1
    fi
}

git() {
    _wtf_last_cmd="git $*"
    if [[ "$1" == "push" ]]; then
        printf 'error: src refspec my-feature does not match any\n'
        printf 'error: failed to push some refs to '"'"'git@github.com:you/repo.git'"'"'\n'
        _wtf_last_exit=128
        return 128
    fi
    command git "$@"
    _wtf_last_exit=$?
}
