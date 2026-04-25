#!/usr/bin/env python3
"""
Read GetConversationHistory JSON response from stdin, render as HTML, open in browser.
Usage: python3 render.py <conversation_uuid> < grpcurl_response.json
"""

import json
import sys
import html
import tempfile
import webbrowser
from pathlib import Path


import re as _re


def _get(block: dict, *keys):
    """Try multiple key names (handles both snake_case and camelCase)."""
    for k in keys:
        if k in block:
            return block[k]
    return None


def render_content_block(block: dict) -> str:
    """Render a single MessageContent block as HTML.
    Handles both snake_case (save payload) and camelCase (chatstore gRPC-JSON response).
    """
    md = _get(block, "markdown")
    tc = _get(block, "tool_call", "toolCall")
    tr = _get(block, "tool_response", "toolResponse")
    rs = _get(block, "reasoning")

    if md is not None:
        text = html.escape(md.get("content", ""))
        # Basic markdown: code blocks, inline code, bold
        text = text.replace("```", "<pre-fence>")
        parts = text.split("<pre-fence>")
        out = []
        for i, part in enumerate(parts):
            if i % 2 == 1:
                # Strip optional language hint on first line (e.g. "bash\n...")
                if "\n" in part:
                    first, rest = part.split("\n", 1)
                    if first.strip() and " " not in first.strip():
                        part = rest  # drop language hint line
                out.append(f'<pre>{part}</pre>')
            else:
                part = _re.sub(r'`([^`]+)`', r'<code>\1</code>', part)
                part = _re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', part)
                part = part.replace("\n", "<br>")
                out.append(part)
        return '<div class="markdown">' + "".join(out) + '</div>'

    elif tc is not None:
        name = html.escape(tc.get("name", ""))
        tool_id = html.escape(tc.get("tool_call_id") or tc.get("toolCallId") or "")
        inp = tc.get("input", "")
        if isinstance(inp, str):
            try:
                inp = json.dumps(json.loads(inp), indent=2)
            except Exception:
                pass
        elif isinstance(inp, dict):
            inp = json.dumps(inp, indent=2)
        inp = html.escape(str(inp))
        return f'''<div class="tool-call">
  <div class="tool-label">⚙ Tool call: <strong>{name}</strong> <span class="tool-id">{tool_id}</span></div>
  <pre>{inp}</pre>
</div>'''

    elif tr is not None:
        name = html.escape(tr.get("name", "") or tr.get("title", "tool_result"))
        tool_id = html.escape(tr.get("tool_call_id") or tr.get("toolCallId") or "")
        output = html.escape(tr.get("output", ""))
        status = tr.get("status", "")
        status_class = "error" if "ERROR" in status else "success"
        return f'''<div class="tool-response {status_class}">
  <div class="tool-label">↩ Tool result: <strong>{name}</strong> <span class="tool-id">{tool_id}</span></div>
  <pre>{output}</pre>
</div>'''

    elif rs is not None:
        text = html.escape(rs.get("content", ""))
        text = text.replace("\n", "<br>")
        return f'<div class="reasoning"><span class="reasoning-label">Reasoning</span><div>{text}</div></div>'

    else:
        return f'<div class="unknown">{html.escape(json.dumps(block))}</div>'


def render_message(msg: dict, index: int) -> str:
    role = msg.get("role", "")
    contents = msg.get("messageContents", [])
    model = msg.get("modelName", "")

    role_label = {
        "CHAT_STORE_ROLE_USER": "User",
        "CHAT_STORE_ROLE_ASSISTANT": "Assistant",
        "CHAT_STORE_ROLE_TOOL": "Tool",
        "CHAT_STORE_ROLE_DEVELOPER": "System",
    }.get(role, role)

    role_class = {
        "CHAT_STORE_ROLE_USER": "user",
        "CHAT_STORE_ROLE_ASSISTANT": "assistant",
        "CHAT_STORE_ROLE_TOOL": "tool",
        "CHAT_STORE_ROLE_DEVELOPER": "system",
    }.get(role, "unknown")

    model_tag = f'<span class="model">{html.escape(model)}</span>' if model else ""

    blocks_html = "\n".join(render_content_block(b) for b in contents)

    return f'''<div class="message {role_class}">
  <div class="message-header">
    <span class="role">{role_label}</span>{model_tag}
  </div>
  <div class="message-body">{blocks_html}</div>
</div>'''


def build_html(conversation_uuid: str, messages: list) -> str:
    messages_html = "\n".join(render_message(m, i) for i, m in enumerate(messages))
    count = len(messages)

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Conversation {conversation_uuid[:8]}...</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 14px;
      background: #f5f5f5;
      color: #1a1a1a;
      line-height: 1.6;
    }}
    header {{
      background: #1a1a2e;
      color: #eee;
      padding: 16px 24px;
      position: sticky;
      top: 0;
      z-index: 10;
      display: flex;
      align-items: center;
      gap: 16px;
    }}
    header h1 {{ font-size: 16px; font-weight: 600; }}
    header .meta {{ font-size: 12px; color: #aaa; }}
    .container {{
      max-width: 860px;
      margin: 24px auto;
      padding: 0 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }}
    .message {{
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 1px 3px rgba(0,0,0,0.08);
    }}
    .message-header {{
      padding: 8px 16px;
      font-size: 12px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 8px;
    }}
    .message-body {{
      padding: 12px 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }}
    .user .message-header   {{ background: #e8f4fd; color: #1565c0; }}
    .user                   {{ background: #fff; }}
    .assistant .message-header {{ background: #e8f5e9; color: #2e7d32; }}
    .assistant              {{ background: #fff; }}
    .system .message-header {{ background: #fff3e0; color: #e65100; }}
    .system                 {{ background: #fff; }}
    .tool .message-header   {{ background: #f3e5f5; color: #6a1b9a; }}
    .tool                   {{ background: #fff; }}
    .model {{
      font-weight: 400;
      color: #888;
      font-size: 11px;
    }}
    .markdown {{ white-space: pre-wrap; word-break: break-word; }}
    pre {{
      background: #1e1e1e;
      color: #d4d4d4;
      border-radius: 6px;
      padding: 12px;
      overflow-x: auto;
      font-size: 12px;
      line-height: 1.5;
    }}
    code {{ font-family: "JetBrains Mono", "Fira Code", monospace; }}
    .markdown code {{
      background: #f0f0f0;
      color: #1a1a1a;
      padding: 1px 5px;
      border-radius: 3px;
      font-size: 12px;
    }}
    pre code, .markdown pre code {{
      background: none !important;
      color: inherit !important;
      padding: 0;
      border-radius: 0;
      font-size: inherit;
    }}
    .tool-call, .tool-response {{
      border-radius: 6px;
      overflow: hidden;
      border: 1px solid #e0e0e0;
    }}
    .tool-label {{
      padding: 6px 12px;
      font-size: 12px;
      background: #f8f8f8;
      border-bottom: 1px solid #e0e0e0;
    }}
    .tool-call .tool-label  {{ background: #fff8e1; }}
    .tool-response.success .tool-label {{ background: #e8f5e9; }}
    .tool-response.error .tool-label   {{ background: #ffebee; }}
    .tool-id {{ color: #aaa; font-size: 11px; margin-left: 4px; }}
    .tool-call pre, .tool-response pre {{
      margin: 0;
      border-radius: 0;
      max-height: 300px;
    }}
    .reasoning {{
      background: #fafafa;
      border-left: 3px solid #bbb;
      padding: 8px 12px;
      border-radius: 0 4px 4px 0;
      font-size: 13px;
      color: #555;
    }}
    .reasoning-label {{
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      color: #999;
      display: block;
      margin-bottom: 4px;
    }}
  </style>
</head>
<body>
  <header>
    <h1>Claude Code Conversation</h1>
    <span class="meta">{count} messages · {conversation_uuid}</span>
  </header>
  <div class="container">
    {messages_html}
  </div>
</body>
</html>'''


if __name__ == "__main__":
    conversation_uuid = sys.argv[1] if len(sys.argv) > 1 else "unknown"

    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: could not parse grpcurl response: {e}", file=sys.stderr)
        sys.exit(1)

    messages = data.get("messages", [])
    if not messages:
        print("No messages found in response.", file=sys.stderr)
        sys.exit(1)

    print(f"  {len(messages)} messages received", file=sys.stderr)

    html_content = build_html(conversation_uuid, messages)

    out = Path(tempfile.mktemp(suffix=".html", prefix="chatstore-"))
    out.write_text(html_content, encoding="utf-8")
    print(f"  Opening {out}", file=sys.stderr)
    webbrowser.open(f"file://{out}")
