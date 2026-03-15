#!/usr/bin/env zsh
# =============================================================================
# tests/run.zsh — test suite for wtf.zsh
#
# Usage:
#   zsh tests/run.zsh
#
# Output is TAP-compatible (https://testanything.org).
# Exit code: 0 if all pass, 1 if any fail.
# =============================================================================

setopt LOCAL_OPTIONS NO_UNSET

WTF_DIR="${0:A:h:h}"
source "${WTF_DIR}/wtf.zsh"

# ── TAP helpers ───────────────────────────────────────────────────────────────
typeset -g  TAP_COUNT=0
typeset -gi TAP_FAILED=0

_pass() { (( ++TAP_COUNT )); printf 'ok %d - %s\n' "$TAP_COUNT" "$1"; }

_fail() {
    (( ++TAP_COUNT )); (( ++TAP_FAILED ))
    printf 'not ok %d - %s\n' "$TAP_COUNT" "$1"
    [[ -n "${2-}" ]] && printf '  # expected: %s\n' "$2"
    [[ -n "${3-}" ]] && printf '  # got:      %s\n' "$3"
}

assert_eq() {
    local desc="$1" expected="$2" got="$3"
    [[ "$expected" == "$got" ]] && _pass "$desc" || _fail "$desc" "$expected" "$got"
}

assert_neq() {
    local desc="$1" unexpected="$2" got="$3"
    [[ "$unexpected" != "$got" ]] && _pass "$desc" || _fail "$desc" "not '$unexpected'" "$got"
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    [[ "$haystack" == *"$needle"* ]] && _pass "$desc" \
        || _fail "$desc" "*${needle}*" "${haystack:-(empty)}"
}

assert_empty() {
    local desc="$1" val="$2"
    [[ -z "$val" ]] && _pass "$desc" || _fail "$desc" "(empty)" "$val"
}

assert_nonempty() {
    local desc="$1" val="$2"
    [[ -n "$val" ]] && _pass "$desc" || _fail "$desc" "(non-empty)" "(empty)"
}

assert_file_contains() {
    local desc="$1" needle="$2" file="$3"
    local content=""
    [[ -f "$file" ]] && content=$(<"$file")
    [[ "$content" == *"$needle"* ]] && _pass "$desc" \
        || _fail "$desc" "*${needle}*" "${content:-(file empty or missing)}"
}

# Run a snippet in an isolated zsh -c subshell with wtf.zsh pre-sourced.
# Usage: _run_isolated 'zsh code here'  → stdout of the snippet
_run_isolated() {
    zsh -c "
        source '${WTF_DIR}/wtf.zsh'
        ${1}
    " 2>/dev/null
}

# ── Section header ────────────────────────────────────────────────────────────
_section() { printf '\n# %s\n' "$1"; }

# =============================================================================
_section "1. JSON escape"
# =============================================================================

assert_eq "escapes backslash"          'hello\\world'  "$(_wtf_json_escape 'hello\world')"
assert_eq "escapes double quote"       'say \"hi\"'    "$(_wtf_json_escape 'say "hi"')"
assert_eq "escapes newline"            'line1\nline2'  "$(_wtf_json_escape $'line1\nline2')"
assert_eq "escapes tab"                'col1\tcol2'    "$(_wtf_json_escape $'col1\tcol2')"
assert_eq "escapes carriage return"    'a\rb'          "$(_wtf_json_escape $'a\rb')"
assert_eq "empty string"              ''               "$(_wtf_json_escape '')"
assert_eq "no special chars unchanged" 'hello world'  "$(_wtf_json_escape 'hello world')"

# Backslash must be escaped before quote — input '\' + '"' → '\\' + '\"' → '\\"'
# In single-quote notation: four raw chars \  \  \  " = '\\\"'
assert_eq 'backslash+quote: \\" → \\\"' \
    '\\\"' "$(_wtf_json_escape '\"')"

# =============================================================================
_section "2. Guards — wtf exits early when there is nothing to explain"
# =============================================================================
# Each guard test runs in an isolated subshell so variable state is clean.

# Guard: no command captured yet
out=$(_run_isolated 'wtf')
assert_contains "no command: prints 'No command captured'" "No command captured" "$out"

# Guard: last command succeeded (exit 0)
out=$(_run_isolated '
    _wtf_last_cmd="echo hello"
    _wtf_last_exit=0
    wtf
')
assert_contains "exit 0: prints 'exited cleanly'" "exited cleanly" "$out"

# Guard: help flag exits cleanly and shows usage
out=$(_run_isolated 'wtf --help')
assert_contains "--help: shows wtf header"   "wtf"       "$out"
assert_contains "--help: mentions --verbose" "--verbose" "$out"

out=$(_run_isolated 'wtf -h')
assert_contains "-h: shows wtf header" "wtf" "$out"

# =============================================================================
_section "3. Hook state — preexec and precmd manage state correctly"
# =============================================================================
# All hook tests run in isolated subshells — _wtf_preexec uses exec to redirect
# the calling shell's stderr fds, which would corrupt the test runner if called
# directly in the parent process.

# preexec records the command string
result=$(_run_isolated '
    _wtf_preexec "git push origin main"
    printf "%s" "$_wtf_last_cmd"
')
assert_eq "preexec: sets _wtf_last_cmd" "git push origin main" "$result"

# preexec activates capture
result=$(_run_isolated '
    _wtf_preexec "ls /nope"
    printf "%s" "$_wtf_capture_active"
')
assert_eq "preexec: sets _wtf_capture_active=1" "1" "$result"

# preexec creates a stderr temp file
result=$(_run_isolated '
    _wtf_preexec "failing-cmd"
    [[ -f "$_wtf_stderr_file" ]] && echo "exists" || echo "missing"
')
assert_eq "preexec: creates stderr temp file" "exists" "$result"

# preexec skips 'wtf' — must not overwrite last_cmd or activate capture
result=$(_run_isolated '
    _wtf_last_cmd="previous-cmd"
    _wtf_preexec "wtf"
    printf "%s|%s" "$_wtf_last_cmd" "$_wtf_capture_active"
')
assert_eq "preexec: skips 'wtf' — last_cmd unchanged"    "previous-cmd|0" "$result"

# preexec skips 'wtf' with flags
result=$(_run_isolated '
    _wtf_last_cmd="previous-cmd"
    _wtf_preexec "wtf --verbose"
    printf "%s" "$_wtf_last_cmd"
')
assert_eq "preexec: skips 'wtf --verbose'" "previous-cmd" "$result"

# preexec skips 'why' alias
result=$(_run_isolated '
    _wtf_last_cmd="previous-cmd"
    _wtf_preexec "why"
    printf "%s" "$_wtf_last_cmd"
')
assert_eq "preexec: skips 'why' alias" "previous-cmd" "$result"

# precmd captures exit code
result=$(_run_isolated '
    _wtf_capture_active=1
    (exit 42); _wtf_precmd
    printf "%s" "$_wtf_last_exit"
')
assert_eq "precmd: captures exit 42" "42" "$result"

# precmd captures exit 1
result=$(_run_isolated '
    _wtf_capture_active=1
    (exit 1); _wtf_precmd
    printf "%s" "$_wtf_last_exit"
')
assert_eq "precmd: captures exit 1" "1" "$result"

# precmd does NOT update exit when capture is inactive (wtf was the last cmd)
result=$(_run_isolated '
    _wtf_last_exit=99
    _wtf_capture_active=0
    (exit 0); _wtf_precmd
    printf "%s" "$_wtf_last_exit"
')
assert_eq "precmd: does not overwrite exit when inactive" "99" "$result"

# precmd clears capture_active after firing
result=$(_run_isolated '
    _wtf_capture_active=1
    (exit 5); _wtf_precmd
    printf "%s" "$_wtf_capture_active"
')
assert_eq "precmd: clears capture_active after firing" "0" "$result"

# precmd clears _wtf_saved_stderr_fd
result=$(_run_isolated '
    _wtf_preexec "some-cmd"
    (exit 1); _wtf_precmd
    printf "%s" "$_wtf_saved_stderr_fd"
')
assert_empty "precmd: clears _wtf_saved_stderr_fd" "$result"

# =============================================================================
_section "4. Stderr capture — stderr is written to temp file and fd restored"
# =============================================================================

# Stderr written to temp file while still appearing on terminal
stderr_in_file=$(_run_isolated '
    _wtf_preexec "failing-cmd"
    printf "captured error line\n" >&2
    (exit 1); _wtf_precmd
    sleep 0.1   # allow tee subprocess to flush before reading
    cat "$_wtf_stderr_file"
')
assert_contains "stderr: error text written to temp file" \
    "captured error line" "$stderr_in_file"

# stderr fd is restored after precmd (writing >&2 after does not error)
fd_ok=$(_run_isolated '
    _wtf_preexec "some-cmd"
    (exit 1); _wtf_precmd
    printf "restored\n" >&2
    echo ok
')
assert_eq "stderr: fd restored after precmd" "ok" "$fd_ok"

# Second command overwrites state from first
multi=$(_run_isolated '
    _wtf_preexec "first-cmd"
    printf "first error\n" >&2
    (exit 2); _wtf_precmd
    sleep 0.05

    _wtf_preexec "second-cmd"
    printf "second error\n" >&2
    (exit 3); _wtf_precmd
    sleep 0.05

    printf "%s|%s\n" "$_wtf_last_cmd" "$_wtf_last_exit"
    cat "$_wtf_stderr_file"
')
assert_contains "stderr: last_cmd updated on second run"  "second-cmd"   "$multi"
assert_contains "stderr: last_exit updated on second run" "3"            "$multi"
assert_contains "stderr: temp file reflects second run"   "second error" "$multi"

# =============================================================================
_section "5. Transport dispatch"
# =============================================================================

# API key set → _wtf_via_api is called
api_out=$(_run_isolated '
    _wtf_via_api() { printf "__API__"; }
    _wtf_via_mcp() { printf "__MCP__"; }
    ANTHROPIC_API_KEY="test-key" _wtf_send_to_claude "prompt"
')
assert_eq  "dispatch: API key set → calls _wtf_via_api"    "__API__" "$api_out"
assert_neq "dispatch: API key set → skips _wtf_via_mcp"    "__MCP__" "$api_out"

# No API key → _wtf_via_mcp is called
mcp_out=$(_run_isolated '
    _wtf_via_api() { printf "__API__"; }
    _wtf_via_mcp() { printf "__MCP__"; return 0; }
    unset ANTHROPIC_API_KEY
    _wtf_send_to_claude "prompt"
')
assert_eq  "dispatch: no API key → calls _wtf_via_mcp"     "__MCP__" "$mcp_out"
assert_neq "dispatch: no API key → skips _wtf_via_api"     "__API__" "$mcp_out"

# No API key, claude not available → setup message printed
setup_out=$(_run_isolated '
    _wtf_via_mcp() { return 2; }
    unset ANTHROPIC_API_KEY
    _wtf_send_to_claude "prompt"
')
assert_contains "dispatch: no transport → mentions ANTHROPIC_API_KEY" \
    "ANTHROPIC_API_KEY" "$setup_out"
assert_contains "dispatch: no transport → mentions Claude Code" \
    "Claude Code" "$setup_out"

# _wtf_via_mcp returns sentinel 2 when claude binary is absent
no_claude_rc=$(_run_isolated '
    command() {
        if [[ "$1" == "-v" && "$2" == "claude" ]]; then return 1; fi
        builtin command "$@"
    }
    _wtf_via_mcp "prompt" >/dev/null 2>&1
    printf "%d" $?
')
assert_eq "mcp: returns 2 when claude binary absent" "2" "$no_claude_rc"

# =============================================================================
_section "6. Prompt construction"
# =============================================================================
# _wtf_send_to_claude is called inside a pipeline in wtf(), so variable
# assignments inside a mock won't persist.  We use a temp file instead.

# Basic prompt includes command, exit code, and stderr text
prompt_basic=$(_run_isolated '
    _wtf_last_cmd="npm install"
    _wtf_last_exit=1
    _wtf_stderr_file=$(mktemp)
    printf "ENOENT package.json\n" > "$_wtf_stderr_file"

    PROMPT_FILE=$(mktemp)
    _wtf_send_to_claude() { printf "%s" "$1" > "$PROMPT_FILE"; }

    wtf >/dev/null 2>&1

    cat "$PROMPT_FILE"
    rm -f "$PROMPT_FILE"
')
assert_contains "prompt: includes failed command"  "npm install"         "$prompt_basic"
assert_contains "prompt: includes exit code"       "Exit code: 1"        "$prompt_basic"
assert_contains "prompt: includes stderr text"     "ENOENT package.json" "$prompt_basic"
assert_contains "prompt: asks for explanation"     "Explain what went"   "$prompt_basic"

# --verbose flag adds history, cwd, and OS
prompt_verbose=$(_run_isolated '
    _wtf_last_cmd="git push"
    _wtf_last_exit=128
    _wtf_stderr_file=$(mktemp)

    PROMPT_FILE=$(mktemp)
    _wtf_send_to_claude() { printf "%s" "$1" > "$PROMPT_FILE"; }

    wtf --verbose >/dev/null 2>&1

    cat "$PROMPT_FILE"
    rm -f "$PROMPT_FILE"
')
assert_contains "prompt --verbose: includes working directory" "Working directory" "$prompt_verbose"
assert_contains "prompt --verbose: includes OS info"          "OS:"               "$prompt_verbose"

# Prompt uses "none captured" when stderr file is empty
prompt_no_stderr=$(_run_isolated '
    _wtf_last_cmd="bad-cmd"
    _wtf_last_exit=127
    _wtf_stderr_file=$(mktemp)   # empty file

    PROMPT_FILE=$(mktemp)
    _wtf_send_to_claude() { printf "%s" "$1" > "$PROMPT_FILE"; }

    wtf >/dev/null 2>&1

    cat "$PROMPT_FILE"
    rm -f "$PROMPT_FILE"
')
assert_contains "prompt: empty stderr → 'none captured'" "none captured" "$prompt_no_stderr"

# =============================================================================
_section "7. Aliases"
# =============================================================================

alias_val=$(alias why 2>/dev/null)
assert_contains "alias: 'why' is defined"       "why" "$alias_val"
assert_contains "alias: 'why' expands to 'wtf'" "wtf" "$alias_val"

# 'why' with no command captured behaves identically to wtf
out=$(why 2>&1)
assert_contains "alias: 'why' triggers no-command guard" "No command captured" "$out"

# 'wtf why' passes 'why' as an ignored positional arg — same guard fires
out=$(wtf why 2>&1)
assert_contains "alias: 'wtf why' triggers no-command guard" "No command captured" "$out"

# =============================================================================
# TAP plan + summary
# =============================================================================
printf '\n1..%d\n' "$TAP_COUNT"

if (( TAP_FAILED > 0 )); then
    printf '# %d of %d test(s) FAILED\n' "$TAP_FAILED" "$TAP_COUNT" >&2
    exit 1
else
    printf '# All %d tests passed.\n' "$TAP_COUNT"
    exit 0
fi
