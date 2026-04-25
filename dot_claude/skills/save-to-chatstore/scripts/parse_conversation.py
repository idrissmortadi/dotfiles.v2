#!/usr/bin/env python3
"""
Parse a Claude Code JSONL conversation file and emit a grpcurl-ready JSON payload
for chatstore's SaveMessages RPC.

Mapping:
  assistant text block      -> MessageContent { markdown }
  assistant tool_use block  -> MessageContent { tool_call }
  assistant thinking block  -> MessageContent { reasoning }
  user string / text block  -> MessageContent { markdown }
  user tool_result block    -> MessageContent { tool_response }

Usage:
  python3 parse_conversation.py <jsonl_file> <org_id> <user_uuid> <conversation_uuid> <product_id> [title]

Output: JSON string suitable for grpcurl -d '...'
"""

import json
import sys
import uuid
from datetime import timezone, datetime

# Fixed UUID v5 namespace for deriving stable chatstore UUIDs from Claude Code session IDs.
_CC_NS = uuid.UUID("b1a24e00-c1a4-5c0d-e000-000000000001")


def session_conversation_uuid(session_id: str) -> str:
    """Derive a stable conversation UUID from a Claude Code session ID."""
    return str(uuid.uuid5(_CC_NS, session_id))


# ---------------------------------------------------------------------------
# Content block converters — each returns a MessageContent dict
# ---------------------------------------------------------------------------

def mc_markdown(text: str) -> dict:
    return {"markdown": {"content": text.strip()}}


def mc_reasoning(text: str) -> dict:
    return {"reasoning": {"content": text.strip()}}


def mc_tool_call(block: dict) -> dict:
    inp = block.get("input", {})
    inp_str = json.dumps(inp) if isinstance(inp, dict) else str(inp)
    return {"tool_call": {
        "tool_call_id": block.get("id", ""),
        "name": block.get("name", ""),
        "title": block.get("name", ""),  # no separate title in Claude Code
        "input": inp_str,
    }}


def mc_tool_response(block: dict) -> dict:
    content = block.get("content", "")
    is_error = block.get("is_error", False)

    if isinstance(content, str):
        output = content
    elif isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict):
                if item.get("type") == "text":
                    parts.append(item.get("text", ""))
                elif item.get("type") == "tool_reference":
                    parts.append(f"(tool reference: {item.get('tool_name', '')})")
                else:
                    parts.append(json.dumps(item))
            else:
                parts.append(str(item))
        output = "\n".join(p for p in parts if p)
    else:
        output = str(content)

    # Truncate very large tool outputs to stay within 20 MiB request limit
    if len(output) > 20_000:
        output = output[:20_000] + "\n\n[truncated]"

    return {"tool_response": {
        "tool_call_id": block.get("tool_use_id", ""),
        "name": "tool_result",
        "title": "Tool Result",
        "output": output,
        "status": "TOOL_RESPONSE_STATUS_ERROR" if is_error else "TOOL_RESPONSE_STATUS_SUCCESS",
    }}


# ---------------------------------------------------------------------------
# Per-entry parsers
# ---------------------------------------------------------------------------

def message_contents_from_assistant(content: list) -> list:
    result = []
    for item in content:
        if not isinstance(item, dict):
            continue
        t = item.get("type")
        if t == "text":
            text = item.get("text", "").strip()
            if text:
                result.append(mc_markdown(text))
        elif t == "tool_use":
            result.append(mc_tool_call(item))
        elif t == "thinking":
            text = item.get("thinking", "").strip()
            if text:
                result.append(mc_reasoning(text))
    return result


def message_contents_from_user(content) -> list:
    if isinstance(content, str):
        text = content.strip()
        if any(tag in text for tag in ["<local-command", "<system-reminder", "<command-name>"]):
            return []
        return [mc_markdown(text)] if text else []

    if isinstance(content, list):
        result = []
        for item in content:
            if not isinstance(item, dict):
                continue
            t = item.get("type")
            if t == "text":
                text = item.get("text", "").strip()
                if text:
                    result.append(mc_markdown(text))
            elif t == "tool_result":
                result.append(mc_tool_response(item))
        return result

    return []


# ---------------------------------------------------------------------------
# Main parser
# ---------------------------------------------------------------------------

def parse_jsonl(path: str):
    """Yield (role, [MessageContent dict, ...], timestamp, model) tuples."""
    seen_uuids = set()

    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            if entry.get("isSidechain"):
                continue

            entry_type = entry.get("type")
            entry_uuid = entry.get("uuid")
            timestamp = entry.get("timestamp", "")

            if entry_uuid:
                if entry_uuid in seen_uuids:
                    continue
                seen_uuids.add(entry_uuid)

            if entry_type == "user":
                if entry.get("isMeta"):
                    continue
                msg = entry.get("message", {})
                if msg.get("role") != "user":
                    continue
                contents = message_contents_from_user(msg.get("content", ""))
                if contents:
                    yield ("user", contents, timestamp, "")

            elif entry_type == "assistant":
                msg = entry.get("message", {})
                if msg.get("role") != "assistant":
                    continue
                content = msg.get("content", [])
                if not isinstance(content, list):
                    continue
                contents = message_contents_from_assistant(content)
                if contents:
                    yield ("assistant", contents, timestamp, msg.get("model", ""))


# ---------------------------------------------------------------------------
# Payload builder
# ---------------------------------------------------------------------------

def _derive_title(messages: list) -> str:
    """Extract first user message text, truncated to 80 chars, as title."""
    for msg in messages:
        if msg.get("role") != "CHAT_STORE_ROLE_USER":
            continue
        for mc in msg.get("message_contents", []):
            text = mc.get("markdown", {}).get("content", "").strip()
            if text:
                # Single line, truncated
                line = text.split("\n")[0].strip()
                return line[:80] + ("…" if len(line) > 80 else "")
    return ""

ROLE_MAP = {
    "user": "CHAT_STORE_ROLE_USER",
    "assistant": "CHAT_STORE_ROLE_ASSISTANT",
}


def build_payload(jsonl_path, org_id, user_uuid, session_id, product_id, title=None):
    conversation_uuid = session_conversation_uuid(session_id)
    messages = []

    for role, contents, timestamp, model in parse_jsonl(jsonl_path):
        msg = {
            "message_uuid": str(uuid.uuid4()),
            "role": ROLE_MAP[role],
            "message_contents": contents,
        }
        if model:
            msg["model_name"] = model
            msg["model_provider"] = "MODEL_PROVIDER_ANTHROPIC"
        messages.append(msg)

    if not messages:
        print("ERROR: no messages found in conversation file", file=sys.stderr)
        sys.exit(1)

    if title is None:
        title = _derive_title(messages) or f"Claude Code session - {datetime.now(timezone.utc).strftime('%Y-%m-%d')}"

    print(f"INFO: {len(messages)} messages parsed", file=sys.stderr)

    return {
        "org_id": int(org_id),
        "user_uuid": user_uuid,
        "conversation_uuid": conversation_uuid,
        "product_id": product_id,
        "conversation_title": title,
        "messages": messages,
    }


if __name__ == "__main__":
    if len(sys.argv) < 6:
        print(
            f"Usage: {sys.argv[0]} <jsonl_file> <org_id> <user_uuid> <session_id> <product_id> [title]",
            file=sys.stderr,
        )
        sys.exit(1)

    jsonl_file, org_id, user_uuid, session_id, product_id = sys.argv[1:6]
    title = sys.argv[6] if len(sys.argv) > 6 else None

    payload = build_payload(jsonl_file, org_id, user_uuid, session_id, product_id, title)
    # Print the derived conversation_uuid so the skill can use it for delete + report
    print(f"CONVERSATION_UUID={payload['conversation_uuid']}", file=sys.stderr)
    print(json.dumps(payload))
