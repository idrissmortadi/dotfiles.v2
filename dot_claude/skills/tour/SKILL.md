---
name: tour
description: Slash command that produces an ordered, linear tour of a codebase to answer a comprehension question. Reads the relevant code, commits to a reading order, and emits a JSON artifact pinned to the current commit. Use when the user invokes `/tour <question>`.
---

# /tour

## Purpose

Given a comprehension question about a codebase, read the relevant code and produce an ordered linear tour: a sequence of file:line stops, each with a short note explaining why that stop matters for the question. The artifact is ephemeral, pinned to a commit, and consumable by any client (Neovim plugin, terminal renderer, plain reading).

This skill is invoked exclusively through the slash command `/tour <question>`. It does not trigger on inferred intent.

## Inputs

- **Question**: free-form text following `/tour`. If empty, ask exactly one clarifying question, then stop and wait. Do not guess.
- **Scope hints** (implicit): files, directories, or symbols already referenced in the current conversation. Use these to narrow reading; do not require them.
- **Working directory**: the repo root. Resolve via `git rev-parse --show-toplevel`.
- **Commit SHA**: the current `HEAD`. Resolve via `git rev-parse HEAD`. The tour is pinned to this SHA.

If the working directory is not a git repository, stop and tell the user `/tour` requires a git-tracked codebase.

## Procedure

1. **Restate the question** in one sentence to confirm understanding. Keep it as the `question` field of the artifact verbatim from the user; the restatement is for the user, not the artifact.
2. **Capture the pin**: read `HEAD` and `repo_root`.
3. **Plan the reading**, briefly. Identify the entry points or symbols most likely to answer the question. Prefer symbol search and grep over reading whole files.
4. **Read iteratively**, narrowing as you go. Each read should either contribute a stop or rule out a region. Stop reading when adding stops stops adding signal — typically 3 to 8 stops for a focused question, up to ~12 for a broader one. If you find yourself wanting more than 12, the question is too broad: stop and propose a narrower one.
5. **Order the stops** so each one builds on the previous. The first stop is the most natural entry point for the question. The last stop is where the answer is most directly visible. Use `depends_on` when a stop's note assumes the user has read earlier stops.
6. **Write a `summary`**: one to three sentences answering the question at a high level, before the user walks the tour. The tour proves the summary; the summary lets the user decide whether to walk it.
7. **Populate `unresolved`** with anything you noticed but did not trace. An empty list is a claim of completeness — only emit it empty if you genuinely covered everything relevant.
8. **Emit the artifact** twice: once in a fenced ```json block in the reply, once written to `/tmp/tour-<short-sha>-<timestamp>.json`. Update the symlink `/tmp/tour-latest.json` to point at the new file. Print the absolute path in the reply.

## What makes a good stop

- **Anchored**: real `file` and `line` at the pinned commit. Verify the line exists and contains what the note claims.
- **Necessary**: removing it would weaken the tour's answer to the question.
- **Distinct**: not redundant with adjacent stops. If two stops would say nearly the same thing, merge them or drop one.
- **Why, not what**: the `note` explains why this location matters for the question. It does not paraphrase the code — the client can show the code itself.
- **Single paragraph**: a stop's note is one short paragraph. If you need more, the stop is doing too much; split it.

A stop that just says "this is the function" is not a stop. A stop that explains why this function is the one the question hinges on is.

## Output format

Emit exactly this shape, in a fenced ```json block:

```json
{
  "tour": {
    "question": "<verbatim user question>",
    "commit": "<full SHA>",
    "repo_root": "<absolute path>",
    "summary": "<1-3 sentence high-level answer>",
    "stops": [
      {
        "id": 1,
        "file": "<path relative to repo_root>",
        "line": <1-indexed integer>,
        "symbol": "<optional: enclosing symbol name>",
        "note": "<single paragraph explaining why this stop matters>",
        "depends_on": [<optional: list of earlier stop ids>]
      }
    ],
    "unresolved": [
      "<optional: things noticed but not traced>"
    ]
  }
}
```

Required fields: `question`, `commit`, `repo_root`, `summary`, `stops`, `unresolved`. Each stop requires `id`, `file`, `line`, `note`. `symbol`, `depends_on` are optional. `unresolved` may be an empty list but must be present.

Do not embed code snippets in the artifact. Clients fetch code from the pinned commit.

## Delivery

After emitting the JSON in the reply:

1. Write the artifact to `/tmp/tour-<short-sha>-<timestamp>.json` where `<short-sha>` is the first 7 chars of the commit and `<timestamp>` is `YYYYMMDDTHHMMSS` in local time.
2. Update (or create) the symlink `/tmp/tour-latest.json` to point at the new file.
3. **Validate the artifact** by running the bundled script against the file just written:

   `!python3 <skill_dir>/validate_tour.py /tmp/tour-<short-sha>-<timestamp>.json`

   The script checks structural conformance (required fields, types, no duplicate stop ids, `depends_on` references resolve to earlier stops) and semantic constraints (the pinned commit exists, each stop's `file` exists at that commit, `line` is within the file's length). It exits 0 on success and prints a summary; exits non-zero with a human-readable message on any violation.

   If validation fails, do not claim success. Read the error, fix the artifact (most often: a wrong line number, a missing required field, or a stop pointing at a file that doesn't exist at the pinned commit), rewrite the file, and re-validate. Repeat until it passes.

4. Print the absolute path of the new file in the reply, on its own line, prefixed with `tour written to:`, only after validation passes.

## Failure modes

- **Empty question**: ask one clarifying question, then stop and wait. Do not produce a tour from a guessed question.
- **Question too vague to scope** (e.g. "explain this codebase"): propose two or three narrower questions the user could ask instead, then stop. Do not produce a tour.
- **Scope too large** (the reading would require more than ~12 stops to answer honestly): stop, explain what makes the scope large, and propose a narrowing. Do not produce a partial tour and pretend it's complete.
- **Nothing relevant found**: emit a tour with an empty `stops` list, a `summary` that says plainly that the code does not appear to address the question, and `unresolved` populated with what you searched for and did not find. Do not fabricate stops.
- **Not a git repo**: stop and tell the user `/tour` requires a git-tracked codebase.

## What this skill does not do

- It does not answer follow-up questions about a stop. That is a separate interaction; the user re-engages with the agent normally, referring to a stop by id or location.
- It does not update or re-pin a tour as code changes. Tours are snapshots. To refresh, the user runs `/tour` again.
- It does not branch, fork, or graph the tour. The order is linear.
- It does not persist tours beyond `/tmp`. Reboots clear them; that is intentional.
