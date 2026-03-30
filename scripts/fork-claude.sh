#!/bin/bash
# fork-claude.sh - Launch a new AI session in a new terminal window.
#
# Usage:
#   bash scripts/fork-claude.sh <title> [--provider claude|claude-glm|gemini|codex] <<< "plan content"
#
# Plan content is read from stdin so the caller can do it in one command.
# Default provider: claude

set -euo pipefail

TITLE=""
PROVIDER="claude"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      PROVIDER="${2:-}"
      shift 2
      ;;
    *)
      if [[ -z "$TITLE" ]]; then
        TITLE="$1"
      fi
      shift
      ;;
  esac
done

TITLE="${TITLE:-Fork}"
PROJECT_DIR="${FORK_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

mkdir -p "$PROJECT_DIR/tmp/forks"

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-'
}

SLUG="$(slugify "$TITLE")"
DATE_PREFIX="$(date +%Y%m%d)"
PLAN_FILE="$PROJECT_DIR/tmp/forks/${DATE_PREFIX}-${SLUG}.md"
METADATA_FILE="$PROJECT_DIR/tmp/forks/${DATE_PREFIX}-${SLUG}.json"

cat > "$PLAN_FILE"

if [[ ! -s "$PLAN_FILE" ]]; then
  echo "Error: No plan content provided on stdin" >&2
  exit 1
fi

LAUNCHER="$PROJECT_DIR/tmp/forks/_launcher_${SLUG}_$$.sh"

cat > "$LAUNCHER" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

cd 'PROJECT_DIR_PLACEHOLDER'
echo '=== Forked Session (PROVIDER_PLACEHOLDER) ==='
cat 'PLAN_FILE_PLACEHOLDER'
echo ''
echo '============================='
echo ''

PLAN_CONTENT="$(cat 'PLAN_FILE_PLACEHOLDER')"
SYSTEM_PROMPT="You were forked from another conversation to handle this task. Read the plan below and get started immediately.

${PLAN_CONTENT}"

case "PROVIDER_PLACEHOLDER" in
  claude)
    unset CLAUDECODE
    claude --name "FORK_NAME_PLACEHOLDER" "${SYSTEM_PROMPT}"
    ;;
  claude-glm)
    unset CLAUDECODE
    claude-glm --name "FORK_NAME_PLACEHOLDER" "${SYSTEM_PROMPT}"
    ;;
  gemini)
    gemini "${SYSTEM_PROMPT}"
    ;;
  codex)
    codex "${SYSTEM_PROMPT}"
    ;;
  *)
    echo "Unknown provider: PROVIDER_PLACEHOLDER" >&2
    exit 1
    ;;
esac

echo ''
echo 'Session ended. Press Enter to close.'
read -r
SCRIPT

escape_for_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

sed -i "s|PROJECT_DIR_PLACEHOLDER|$(escape_for_sed "$PROJECT_DIR")|g" "$LAUNCHER"
sed -i "s|PLAN_FILE_PLACEHOLDER|$(escape_for_sed "$PLAN_FILE")|g" "$LAUNCHER"
sed -i "s|FORK_NAME_PLACEHOLDER|$(escape_for_sed "$TITLE")|g" "$LAUNCHER"
sed -i "s|PROVIDER_PLACEHOLDER|$(escape_for_sed "$PROVIDER")|g" "$LAUNCHER"

chmod +x "$LAUNCHER"

python - "$METADATA_FILE" "$TITLE" "$PROVIDER" "$PROJECT_DIR" "$PLAN_FILE" <<'PY'
import json
import sys
from datetime import datetime, timezone

metadata_path, title, provider, project_dir, plan_file = sys.argv[1:]
with open(metadata_path, "w", encoding="utf-8") as f:
    json.dump(
        {
            "title": title,
            "provider": provider,
            "project_dir": project_dir,
            "plan_file": plan_file,
            "launched_at": datetime.now(timezone.utc).isoformat(),
        },
        f,
        ensure_ascii=False,
        indent=2,
    )
PY

launch_in_terminal() {
  local title="$1"
  local launcher="$2"

  if [[ -n "${FORK_TERMINAL:-}" ]]; then
    case "$FORK_TERMINAL" in
      alacritty)
        alacritty --title "$title" -e bash "$launcher" &
        return 0
        ;;
      wt|wt.exe|windows-terminal)
        wt.exe new-tab --title "$title" bash -lc "\"$launcher\"" &
        return 0
        ;;
      *)
        echo "Unsupported FORK_TERMINAL: $FORK_TERMINAL" >&2
        return 1
        ;;
    esac
  fi

  if command -v alacritty >/dev/null 2>&1; then
    alacritty --title "$title" -e bash "$launcher" &
    return 0
  fi

  if command -v wt.exe >/dev/null 2>&1; then
    wt.exe new-tab --title "$title" bash -lc "\"$launcher\"" &
    return 0
  fi

  if command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal -- bash "$launcher" &
    return 0
  fi

  if command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -e bash "$launcher" &
    return 0
  fi

  return 1
}

if ! launch_in_terminal "$TITLE" "$LAUNCHER"; then
  echo "Error: No supported terminal launcher found. Tried alacritty, wt.exe, gnome-terminal, and x-terminal-emulator." >&2
  echo "Set FORK_TERMINAL=alacritty or FORK_TERMINAL=wt to override." >&2
  exit 1
fi

echo "Forked session launched: $TITLE (provider: $PROVIDER)"
echo "Plan: $PLAN_FILE"
echo "Metadata: $METADATA_FILE"
