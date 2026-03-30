---
name: fork
description: "Fork or check forks. `/fork <task>` launches a side session. `/fork status <name>` checks what a fork concluded. Use when the user says /fork, asks to handle something in a side session, or asks to check on a fork."
user-invocable: true
---

# Fork Skill

Opens a new AI session in a separate terminal window for a side-task, so the current conversation can continue uninterrupted. Can also check what a forked session concluded.

## Core principle

**`/fork` is a command, not a request.** Launch immediately — never ask clarifying questions.

**Pass context, don't fetch it.** Write what you already know from this conversation into the plan file. Do NOT make tool calls (reads, greps, etc.) to gather info for the fork — that's the fork's job. If you read a file 30 messages ago and remember something relevant, write it. If you haven't looked at something, don't — just mention it and move on.

## Launching a fork

When invoked with `/fork <task description>`:

1. **Write the plan and launch in a single Bash call** — so the user only needs one `/undo` to roll back the fork from the caller's context:
   ```bash
   SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills/fork"
   if [[ ! -f "$SKILL_DIR/scripts/fork-claude.sh" ]]; then
     SKILL_DIR="$HOME/.claude/skills/fork"
   fi
   bash "$SKILL_DIR/scripts/fork-claude.sh" "<short title>" [--provider claude|claude-glm|gemini|codex] <<'EOF'
   # Fork: <short title>

   ## Do
   <task>

   ## Context
   <what you know>
   EOF
   ```
   The script reads the plan from stdin and writes it to `tmp/forks/` automatically.

   Default provider is `claude`. If the first word of the task matches a provider name, use that provider:
   - `/fork fix the curves` → claude (default)
   - `/fork gemini fix the curves` → gemini
   - `/fork codex fix the curves` → codex
   - `/fork claude-glm fix the curves` → claude-glm (Claude Code with z.ai GLM provider)

2. **Report back** in one line with the fork name, and continue the current conversation.

## Plan file format

```markdown
# Fork: <short title>

## Do
<what needs to be done — one or two sentences>

## Context
<freeform dump of what the caller already knows that's relevant —
things learned during this conversation, decisions made, patterns noticed,
specific values or signatures encountered, current state of things.
No structure required. Don't pad it, don't fetch new info. Just write what's in your head.>
```

That's it. No "Key Files" section, no "Discover" section. The fork has full access to the codebase, MCP tools, and debugger — it can find what it needs.

## Checking fork results

When the user asks to check on a fork — e.g. `/fork status <name>`, "check that fork", "what did the fork say":

1. **Determine the fork name.** This is the `<short title>` that was passed to `fork-claude.sh` when launching. If the user doesn't specify, use the title from the most recent `/fork` launch in this conversation.

2. **Run the check script:**
   ```bash
   SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills/fork"
   if [[ ! -f "$SKILL_DIR/scripts/fork_last_response.py" ]]; then
     SKILL_DIR="$HOME/.claude/skills/fork"
   fi
   python "$SKILL_DIR/scripts/fork_last_response.py" --by-name "<fork title>"
   ```

3. **Report the result.** The script outputs:
   - The last text the forked session produced (truncated to 5000 chars)
   - `[still running]` if the fork hasn't finished yet
   - An error if no matching session was found

You can also check by session UUID if known:
```bash
python "$SKILL_DIR/scripts/fork_last_response.py" <session-uuid-or-path>
```

## Important

- **Never ask the user for more info before launching.**
- **Never make tool calls to prepare the plan file.** Write from memory only.
- Keep the plan file concise — enough for the fork to orient, not a full brief.
- Use a slugified version of the first few words as the filename (e.g., `fix-widget-layout.md`).
- The launcher resolves the current project root dynamically and stores its plan under that project's `tmp/forks/`.
- The packaged scripts live under the skill itself, so the skill works across projects once synced into `~/.claude/skills/` or `~/.codex/skills/`.
- After launching, continue the current conversation normally — don't wait for the fork to finish.
- Report the fork launch in one line, not a paragraph.
