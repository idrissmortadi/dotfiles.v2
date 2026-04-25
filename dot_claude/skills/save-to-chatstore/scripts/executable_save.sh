#!/usr/bin/env bash
# Save the current Claude Code session to chatstore.
# Usage: save.sh <session_id> <jsonl_file> [product_id]
#
# Env overrides:
#   CHATSTORE_ORG_ID      (default: 2)
#   CHATSTORE_ENDPOINT    (default: chatstore.us1.staging.dog:443)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SESSION_ID="${1:?Usage: save.sh <session_id> <jsonl_file> [product_id]}"
JSONL_FILE="${2:?Usage: save.sh <session_id> <jsonl_file> [product_id]}"
PRODUCT_ID="${3:-CHAT_STORE_PRODUCT_ASSISTANT}"
ORG_ID="${CHATSTORE_ORG_ID:-2}"
ENDPOINT="${CHATSTORE_ENDPOINT:-chatstore.us1.staging.dog:443}"

# Derive user UUID from ddtool
echo "→ Resolving user identity..."
USER_UUID=$(ddtool auth whoami 2>/dev/null | grep '^id:' | awk '{print $2}')
if [[ -z "$USER_UUID" ]]; then
  echo "ERROR: could not derive user_uuid from 'ddtool auth whoami'" >&2
  exit 1
fi
echo "  user_uuid: $USER_UUID"

# Build payload (derives conversation_uuid deterministically from session_id)
echo "→ Parsing conversation from $JSONL_FILE..."
STDERR_TMP=$(mktemp)
PAYLOAD=$(python3 "$SCRIPT_DIR/parse_conversation.py" \
  "$JSONL_FILE" "$ORG_ID" "$USER_UUID" "$SESSION_ID" "$PRODUCT_ID" \
  2>"$STDERR_TMP")
cat "$STDERR_TMP" >&2
CONVERSATION_UUID=$(grep '^CONVERSATION_UUID=' "$STDERR_TMP" | cut -d= -f2)
MESSAGE_COUNT=$(grep '^INFO:' "$STDERR_TMP" | grep -oE '[0-9]+' | head -1)
rm "$STDERR_TMP"

echo "  conversation_uuid: $CONVERSATION_UUID"
echo "  messages: $MESSAGE_COUNT"

# Get auth token once, reuse for both calls
echo "→ Getting auth token..."
AUTH_HEADER=$(ddtool auth token rapid-ai-platform-agents --datacenter us1.staging.dog --http-header)

# Delete existing conversation (ignore not-found errors — first run)
echo "→ Clearing existing conversation (if any)..."
grpcurl \
  -H "$AUTH_HEADER" \
  -d "{\"org_id\": $ORG_ID, \"user_uuid\": \"$USER_UUID\", \"conversation_uuid\": \"$CONVERSATION_UUID\", \"mode\": \"DELETE_MESSAGES_MODE_CLEAR_SESSION\"}" \
  "$ENDPOINT" \
  chatstorepb.ChatStore/DeleteMessages 2>/dev/null || true

# Save
echo "→ Saving $MESSAGE_COUNT messages to chatstore..."
grpcurl \
  -H "$AUTH_HEADER" \
  -d "$PAYLOAD" \
  "$ENDPOINT" \
  chatstorepb.ChatStore/SaveMessages

echo ""
echo "✓ Saved to chatstore"
echo ""
echo "Share with colleagues:"
echo "  /view-chatstore-conversation $USER_UUID $CONVERSATION_UUID"
