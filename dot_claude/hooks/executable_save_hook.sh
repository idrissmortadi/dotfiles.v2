#!/bin/bash
# MEMORY SAVE HOOK — Periodic reminder to persist knowledge
#
# Claude Code "Stop" hook. After every assistant response:
# 1. Counts human messages in the session transcript
# 2. Every SAVE_INTERVAL messages, BLOCKS the AI from stopping
# 3. Returns a reason telling the AI to save to Memory system + CLAUDE.md
# 4. AI does the save, then stops normally on the next attempt
#
# === HOW IT WORKS ===
#
# Claude Code sends JSON on stdin with:
#   session_id       — unique session identifier
#   stop_hook_active — true if AI is already in a save cycle (prevents infinite loop)
#   transcript_path  — path to the JSONL transcript file
#
# When we block, the "reason" becomes a system message the AI sees and acts on.
# On the next Stop attempt, stop_hook_active=true so we let it through.

SAVE_INTERVAL=100 # Save every N human messages
STATE_DIR="$HOME/.claude/hooks/state"
mkdir -p "$STATE_DIR"

# Read JSON input from stdin
INPUT=$(cat)

# Parse fields
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','unknown'))" 2>/dev/null)
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)
TRANSCRIPT_PATH="${TRANSCRIPT_PATH/#\~/$HOME}"

# If already in a save cycle, let the AI stop normally (infinite-loop prevention)
if [ "$STOP_HOOK_ACTIVE" = "True" ] || [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  echo "{}"
  exit 0
fi

# Count human messages in the JSONL transcript
if [ -f "$TRANSCRIPT_PATH" ]; then
  EXCHANGE_COUNT=$(
    python3 - "$TRANSCRIPT_PATH" <<'PYEOF'
import json, sys
count = 0
with open(sys.argv[1]) as f:
    for line in f:
        try:
            entry = json.loads(line)
            msg = entry.get('message', {})
            if isinstance(msg, dict) and msg.get('role') == 'user':
                content = msg.get('content', '')
                if isinstance(content, str) and '<command-message>' in content:
                    continue
                count += 1
        except:
            pass
print(count)
PYEOF
    2>/dev/null
  )
else
  EXCHANGE_COUNT=0
fi

# Track last save point for this session
LAST_SAVE_FILE="$STATE_DIR/${SESSION_ID}_last_save"
LAST_SAVE=0
if [ -f "$LAST_SAVE_FILE" ]; then
  LAST_SAVE=$(cat "$LAST_SAVE_FILE")
fi

SINCE_LAST=$((EXCHANGE_COUNT - LAST_SAVE))

echo "[$(date '+%H:%M:%S')] Session $SESSION_ID: $EXCHANGE_COUNT exchanges, $SINCE_LAST since last save" >>"$STATE_DIR/hook.log"

# Time to save?
if [ "$SINCE_LAST" -ge "$SAVE_INTERVAL" ] && [ "$EXCHANGE_COUNT" -gt 0 ]; then
  echo "$EXCHANGE_COUNT" >"$LAST_SAVE_FILE"
  echo "[$(date '+%H:%M:%S')] TRIGGERING SAVE at exchange $EXCHANGE_COUNT" >>"$STATE_DIR/hook.log"

  cat <<'HOOKJSON'
{
  "decision": "block",
  "reason": "PERIODIC MEMORY CHECKPOINT. Before continuing, save what you've learned this session:\n\n1. **Memory system** (memory/ files via auto-memory): Save any of the following that apply:\n   - User preferences, role, or knowledge you discovered (type: user)\n   - Corrections or confirmed approaches from the user (type: feedback)\n   - Project context, decisions, deadlines, or ongoing work (type: project)\n   - Pointers to external resources or documentation (type: reference)\n\n2. **CLAUDE.md**: If you learned any universal tips, patterns, or rules that should apply to ALL future sessions (not just this project), append them to the appropriate section in CLAUDE.md. Examples: tool-specific syntax gotchas, language idioms the user prefers, workflow patterns that proved effective.\n\nOnly save what's genuinely new and non-obvious. Skip if nothing worth persisting. Then continue the conversation."
}
HOOKJSON
else
  echo "{}"
fi
