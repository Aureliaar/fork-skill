# fork-skill

A Claude Code skill that forks the current session into a new terminal window, letting side-tasks run in parallel without interrupting the main conversation.

## What it does

- `/fork <task>` — launches a new AI session in a separate terminal with a plan you dictate, then returns immediately so the main conversation continues
- `/fork status <name>` — checks what a forked session concluded

Supports multiple providers: `claude` (default), `gemini`, `codex`, `claude-glm`.

## Install

```bash
# Clone to your skills directory
git clone https://github.com/sinijaco/fork-skill ~/.claude/skills/fork
```

Or symlink if you cloned elsewhere:

```bash
ln -sf ~/fork-skill ~/.claude/skills/fork
```

## Structure

```
skill.md              # Claude Code skill definition (loaded automatically)
scripts/
  fork-claude.sh      # Launches a new terminal window with a forked session
  fork_last_response.py  # Reads the last response from a forked session log
  fork-last-response.sh  # Thin bash wrapper around the python script
```

## Requirements

- [Claude Code](https://github.com/anthropics/claude-code) (`claude` CLI)
- A supported terminal emulator: Windows Terminal (`wt.exe`), Alacritty, or gnome-terminal
- Python 3 (for `fork_last_response.py`)

Override terminal with `FORK_TERMINAL=wt` or `FORK_TERMINAL=alacritty` if auto-detection fails.
