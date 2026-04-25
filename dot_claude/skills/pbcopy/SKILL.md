---
name: pbcopy
description: Copy text output to the clipboard using pbcopy. Use when the user wants to copy Claude-generated text that isn't tied to a file — Slack messages, commit messages, email drafts, summaries, etc.
allowed-tools: Bash(pbcopy:*)
---

Copy the following text to the clipboard using `pbcopy`.

Do not wrap it in markdown, code fences, or any other formatting — pipe the raw text directly.

Use `printf '%s' '<text>' | pbcopy` (not `echo`) to avoid appending a trailing newline that would show up when pasting.

After copying, confirm with a single short line: "Copied to clipboard."

Do not repeat or display the content.
