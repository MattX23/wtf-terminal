# ⚡ wtf

A zsh plugin that explains the last failed terminal command using Claude AI.

![wtf demo](demo.gif)

```
$ npm install
npm error code ENOENT
npm error syscall open
npm error path /Users/you/package.json

$ wtf

  ⚡ wtf  npm install  (exit 1)

  There's no package.json in the current directory, so npm has nothing to
  install. Either navigate to your project root with cd, or run npm init
  to create a new package.
```

---

## Install

**One-liner:**
```sh
curl -fsSL https://raw.githubusercontent.com/MattX23/wtf-terminal/main/install.sh | sh
source ~/.zshrc
```

**Or clone:**
```sh
git clone https://github.com/MattX23/wtf-terminal.git
cd wtf-terminal && sh install.sh
source ~/.zshrc
```

**Or manually** — add to your `~/.zshrc`:
```zsh
source "/path/to/wtf-terminal/wtf.zsh"
```

---

## Setup

wtf needs a way to reach Claude. It checks in this order:

### Option 1 — Anthropic API key (any Claude plan)

```zsh
export ANTHROPIC_API_KEY="sk-ant-..."
```

Add that line to your `~/.zshrc` to make it permanent. Get a key at
[console.anthropic.com](https://console.anthropic.com).

Uses `claude-haiku-4-5` with streaming, so responses appear immediately.

### Option 2 — Claude Code CLI (Pro subscription, no API key needed)

```sh
npm install -g @anthropic-ai/claude-code
claude   # log in once
```

If `ANTHROPIC_API_KEY` is not set and `claude` is in your PATH, wtf routes
through the Claude Code CLI automatically.

If neither is available, wtf prints a setup guide instead of an error.

---

## Usage

Run any command. If it fails, type `wtf`:

```zsh
git push origin my-branch
wtf
```

Aliases:
```zsh
why          # same as wtf
wtf why      # also works
```

Flags:
```zsh
wtf --verbose   # includes recent history, working directory, and OS info
wtf --help      # show usage
```

---

## How it works

wtf hooks into zsh using `preexec` and `precmd`:

1. **`preexec`** — fires before every command. Records the command string and
   redirects stderr through `tee` so output still appears in your terminal
   *and* gets saved to a temp file.

2. **`precmd`** — fires after every command. Captures the exit code and
   restores stderr.

3. **`wtf`** — reads the saved command, exit code, and stderr. Builds a prompt
   and sends it to Claude. Streams the response directly to your terminal.

```
capture failed command + stderr
             ↓
        build prompt
             ↓
  _wtf_send_to_claude()    ← only this differs by transport
             ↓
   format and print response
```

Everything is contained in a single `.zsh` file with no dependencies beyond
`curl` and standard macOS developer tooling.

---

## Requirements

- **zsh 5.3+** — anonymous fd syntax (`{fd}>&2`) used for stderr capture requires 5.3 or later. macOS ships with 5.9; check yours with `zsh --version`.
- **macOS or Linux**
- **curl** — for the API key transport path
- **Claude Code CLI** (`claude`) — only needed for the Pro/no-key path

---

## Companion tools

wtf is part of a small collection of zsh terminal tools:

- **[cmdwatch](../terminal-alias-suggester/)** — notices repeated mistyped
  commands and offers to create aliases for them

Both tools share the same ⚡ personality and hook pattern, and can be sourced
together in your `.zshrc`.

---

## License

MIT — see [LICENSE](LICENSE).
