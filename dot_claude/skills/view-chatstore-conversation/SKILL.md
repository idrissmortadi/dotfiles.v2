---
name: view-chatstore-conversation
description: Fetch a conversation from chatstore and open it in the browser. Use when the user wants to view or share a saved chatstore conversation.
disable-model-invocation: true
argument-hint: <user_uuid> <conversation_uuid>
allowed-tools: Bash
---

Run the view script:

```bash
bash ~/.claude/skills/save-to-chatstore/scripts/view.sh $ARGUMENTS
```

If no arguments are given, derive them from the current session:

```bash
USER_UUID=$(ddtool auth whoami 2>/dev/null | grep '^id:' | awk '{print $2}')
CONVERSATION_UUID=$(python3 -c "import uuid; NS=uuid.UUID('b1a24e00-c1a4-5c0d-e000-000000000001'); print(uuid.uuid5(NS, '${CLAUDE_SESSION_ID}'))")
bash ~/.claude/skills/save-to-chatstore/scripts/view.sh "$USER_UUID" "$CONVERSATION_UUID"
```

If the script fails, show the error output to the user as-is.
