#!/usr/bin/env bash
# Fetch a conversation from chatstore and open it in the browser.
# Usage: view.sh <user_uuid> <conversation_uuid>
#
# Env overrides:
#   CHATSTORE_ORG_ID    (default: 2)
#   CHATSTORE_ENDPOINT  (default: chatstore.us1.staging.dog:443)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

USER_UUID="${1:?Usage: view.sh <user_uuid> <conversation_uuid>}"
CONVERSATION_UUID="${2:?Usage: view.sh <user_uuid> <conversation_uuid>}"
ORG_ID="${CHATSTORE_ORG_ID:-2}"
ENDPOINT="${CHATSTORE_ENDPOINT:-chatstore.us1.staging.dog:443}"

echo "→ Getting auth token..."
AUTH_HEADER=$(ddtool auth token rapid-ai-platform-agents --datacenter us1.staging.dog --http-header)

echo "→ Fetching conversation $CONVERSATION_UUID..."
RESPONSE=$(grpcurl \
  -H "$AUTH_HEADER" \
  -d "{\"org_id\": $ORG_ID, \"user_uuid\": \"$USER_UUID\", \"conversation_uuid\": \"$CONVERSATION_UUID\"}" \
  "$ENDPOINT" \
  chatstorepb.ChatStore/GetConversationHistory)

echo "→ Rendering..."
python3 "$SCRIPT_DIR/render.py" "$CONVERSATION_UUID" <<< "$RESPONSE"
