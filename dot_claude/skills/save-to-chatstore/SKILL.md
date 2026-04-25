---
name: save-to-chatstore
description: Save the current Claude Code conversation to Datadog's chatstore service. Reads the conversation from the local JSONL file and saves it via grpcurl. Use when the user wants to persist, save, or archive the current session to chatstore.
disable-model-invocation: true
argument-hint: [product_id]
allowed-tools: Bash
---

Run the save script:

```bash
JSONL_FILE=$(find ~/.claude/projects -name "${CLAUDE_SESSION_ID}.jsonl" 2>/dev/null | head -1)
bash ${CLAUDE_SKILL_DIR}/scripts/save.sh "${CLAUDE_SESSION_ID}" "$JSONL_FILE" "$ARGUMENTS"
```

If the script fails, show the error output to the user as-is.
