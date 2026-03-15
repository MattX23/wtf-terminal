#!/usr/bin/env sh
# =============================================================================
# wtf — installer
#
# Usage (one-liner):
#   curl -fsSL https://raw.githubusercontent.com/mattnorthwood/wtf-terminal/main/install.sh | sh
#
# Or clone + install:
#   git clone https://github.com/mattnorthwood/wtf-terminal.git
#   cd wtf-terminal && ./install.sh
# =============================================================================

set -e

INSTALL_DIR="${HOME}/.wtf-terminal"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

# ── Resolve source file ───────────────────────────────────────────────────────
# When piped via curl the script lives in a temp location; when run from a
# cloned repo the file is next to this script.
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "${SCRIPT_DIR}/wtf.zsh" ]; then
    WTF_ZSH="${SCRIPT_DIR}/wtf.zsh"
    IN_PLACE=1
else
    # Download mode — fetch wtf.zsh alongside this installer
    WTF_ZSH="${INSTALL_DIR}/wtf.zsh"
    IN_PLACE=0
fi

echo ""
echo "  ⚡ wtf — installer"
echo ""

# ── Create install dir and download if needed ─────────────────────────────────
if [ "$IN_PLACE" = "0" ]; then
    mkdir -p "$INSTALL_DIR"
    echo "  Downloading wtf.zsh → ${WTF_ZSH}"
    curl -fsSL \
        "https://raw.githubusercontent.com/mattnorthwood/wtf-terminal/main/wtf.zsh" \
        -o "$WTF_ZSH"
else
    # Already on disk (git clone path); just record the path
    WTF_ZSH="${SCRIPT_DIR}/wtf.zsh"
fi

# ── Wire into .zshrc ──────────────────────────────────────────────────────────
SOURCE_LINE="source \"${WTF_ZSH}\""

if grep -qF "$SOURCE_LINE" "$ZSHRC" 2>/dev/null; then
    echo "  Already sourced in ${ZSHRC} — nothing to do."
else
    printf '\n# wtf — AI error explainer\n%s\n' "$SOURCE_LINE" >> "$ZSHRC"
    echo "  Added to ${ZSHRC}"
fi

echo ""
echo "  ✓  Done! Open a new terminal or run:"
echo "     source ${ZSHRC}"
echo ""
echo "  Then run a failing command and type: wtf"
echo ""
echo "  Transport options (wtf checks in this order):"
echo "    1. ANTHROPIC_API_KEY in env  →  streams via Anthropic API"
echo "    2. 'claude' CLI found        →  uses Claude Code (Pro subscription)"
echo ""
