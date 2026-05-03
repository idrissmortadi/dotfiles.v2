# CLAUDE

## Workflow Orchestration

### 1. Plan Mode Default

- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy

- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop

- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done

- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)

- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing

- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests - then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Break work into logical commits upfront — each commit is a discrete unit. Create one todo task per commit so progress maps directly to git history. Goal: the PR must be reviewable commit-by-commit, each commit a coherent self-contained story.
2. **Verify Plan**: For non-trivial or irreversible work, check in before starting implementation.
3. **Track Progress**: Mark tasks complete and commit after each one.
4. **Fixups**: Use `git commit --fixup <sha>` for corrections to a prior commit. Before the PR is marked ready for review, squash with `git rebase --autosquash`. Never leave fixup commits in the final history.

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

## Writing Style

- **Cite code locations with `path:line`**. When referencing any function, variable, struct, constant, map, test, etc., include an absolute or repo-relative path and a line number (e.g. `domains/chatbot/apps/apis/ddvector/shared/repository/embedding_repo.go:681`). Applies to chat, investigation notes, PR bodies, review comments, commit bodies, everything. A bare symbol name is not enough; the user needs to be able to jump to it. If a symbol is referenced multiple times in one response, cite on first mention; re-cite only when pointing at a different line.

## Bazel / bzl

- In `dd-source`, bzl test` also builds, so no need to run `bzl build` separately before testing. Just run `bzl test` directly.
- **Proto regeneration after rebase**: When rebasing a branch with proto changes and generated files conflict, accept `--ours` for all generated files, resolve `.proto` manually (keep both sides), then regenerate with `bzl run //:snapshot -- //path/to/proto/package/...`. This handles all snapshot types (pb.go, grpc, validate, mockgen, proto_doc, python) in the correct dependency order automatically. Do NOT use individual `_snapshot_test_update` targets.
- **No `go` toolchain commands in dd-source**: Always use `bzl` (e.g. `bzl test`, `bzl run`). Never run `go build`, `go test`, `go generate` etc. directly — except `go generate` for mockgen regeneration which is explicitly allowed.

## Pull Request Authoring

Only open a PR when explicitly asked. Use `/pr-write` to generate the description.

When opening a PR:
1. Find the JIRA ticket: branch name → commit messages → ask if not found
2. **Title**: `[JIRA-TICKET] Component: Imperative description` (under 72 chars)
3. **Body**:
   ```
   ## Summary
   [2-3 sentences: what, why, how]

   ## Changes
   - [Functional change 1]
   - [Functional change 2]

   ## Testing
   [Tests written, staging runs, manual steps]
   ```
   For bug fixes, append: `## Bug` with **Root cause**, **Fix**, **Repro** (one line each).
4. Open as draft: `gh pr create --draft --title "..." --body "..."`
5. Post a comment: `gh pr comment <number> --body "@cursor review"`
6. Show the user the PR URL.

For stacked PRs (Graphite): `gt submit --draft --no-edit` to create, then `gh pr edit <N> --title "..." --body "..."` to set metadata (`gt submit` has no `--body` flag).

## GitHub PR Comments

- **Always draft replies first; never post unprompted.** Show every reply (review-thread reply, top-level PR comment, issue comment) as a draft block in chat before any `gh` call. Wait for explicit go-ahead per batch — "post them" / "send" / "ok" — and don't infer approval from earlier "address the feedback" / "commit" instructions, which authorize code changes only. Default mode is draft-and-wait, even in auto mode.
- To reply to a specific review comment thread: `gh api repos/OWNER/REPO/pulls/PR/comments/COMMENT_ID/replies -f body='message'`
- `COMMENT_ID` is the `comment_id` from the first comment in the thread (the one with `in_reply_to_id: null`)
- This posts a reply within the existing thread, not a new top-level comment

## Git history rewrites

- **Always create a backup branch first**: `git branch <branch>.backup-pre-<op> <sha>` before any rebase, squash, reset --hard, or force-push. Unprompted. The cost is one line, the recovery path is invaluable.
- **Stacked PRs: find the real base**: before squashing or rebasing, check `gh pr view <n> --json baseRefName` — do NOT assume `main` is the base. A stacked PR targets a feature branch, and using `git merge-base HEAD main` instead of the actual base will fold the parent PR's commits into the squash. Symptom: GitHub PR UI shows 3-4× more lines than expected, including files the PR doesn't touch (e.g. proto regen from the parent).
- **Squashing branches with deletion commits**: interactive rebase breaks when earlier commits reference code that a later commit deletes (the intermediate tree fails to build/test). Use `git reset --soft <base>` and hand-assemble commits instead — every commit then reflects the final tree state and cannot be broken.
- **Tree-equivalence check**: after any history rewrite, run `git diff <backup-branch> HEAD --stat`. If it's non-empty, the rewrite lost or introduced something. Only force-push when the diff is empty.
- **PR-scope sanity check after squash**: run `git diff <real-pr-base> HEAD --shortstat` and eyeball the file list. If the line count or files don't match what you expected the PR to contain, you likely rebased against the wrong base.
- **Force-push safety**: use `--force-with-lease`, not `--force`. Before pushing, check `gh api repos/OWNER/REPO/pulls/N/comments --jq 'length'` — inline review comments get orphaned by a force-push, so surface them to the user if the PR isn't draft.
- **`git stash pop` with a dirty tree**: if there's already a stash on top of the stack from earlier work, `pop` without arguments can pull the wrong one and create unexpected conflicts. Check `git stash list` first, and prefer `git stash pop stash@{N}` to target a specific entry.

## Go Protobuf

- Generated getter methods (e.g. `GetFields()`, `GetFieldsMappings()`) handle nil receivers, so explicit nil checks before calling them are redundant. A nil map lookup in Go is also safe (returns zero value). Prefer `x.GetFoo().GetBar()` over `x != nil && x.GetFoo() != nil && x.GetFoo().GetBar()`.
- Adding `optional` to a scalar/enum proto3 field flips its Go codegen from value to pointer. Every direct assignment (`req.Field = x`) across the repo fails to compile; every direct read in a test assertion (`req.Field`) compares pointer-vs-value. Before pushing, grep `FieldName:` assignments globally, then read field comparisons in tests, and convert both. Use `req.GetField()` for reads (handles nil), and `&x` or a local variable for writes.

## Postgres upsert: distinguishing INSERT from UPDATE

- **`xmax = 0` is true for freshly INSERTed rows, false for ON CONFLICT updates.** The trick for `INSERT ... ON CONFLICT DO UPDATE` when you need to know whether the row was newly created (e.g. to enforce immutable columns set only at creation): `RETURNING (xmax = 0) AS inserted, immutable_col`. Combined with a WHERE clause on the conflict branch (e.g. `WHERE owner_uuid = EXCLUDED.owner_uuid`), an empty RETURNING (`pgx.ErrNoRows`) means the row exists under a different owner — preserves the old `RowsAffected() == 0` semantic without losing the inserted/updated bit. Reuse pattern: don't update the immutable column in the ON CONFLICT branch (keeps it append-only); on subsequent saves, compare the stored value to the request and reject mismatches with `FailedPrecondition`.

## Schema migrations + image-pinned test containers

- **Adding a column referenced by a SELECT requires the test container schema to ship first.** dd-source's chatstore-style services run Go tests against an Alembic-built Postgres image pinned by sha. New SELECT columns fail every test in the suite with `column "X" does not exist (SQLSTATE 42703)` until the migration lands AND the image rebuilds AND the bzl values file is bumped to the new sha. Mitigation: make the new-column reference conditional on whether the request actually carries the field. Only emit `RETURNING new_col` (or include it in SELECT) when the caller sets it; defer the unconditional read-side projection to a follow-up PR after the test image picks up the migration. Same pattern for any image-pinned-schema test setup.

## grpcurl

- Order matters: flags first, then `-d <json>`, then address, then method — `grpcurl [flags] -d '{...}' host:port pkg.Service/Method`. Swapping method before address or sticking the address inside a flag array gives "Too many arguments."
- Prefer `flag=value` form (`-H=...`, `-import-path=...`) over `-H foo`; avoids tokenizer splitting headers whose values contain spaces (e.g. `Authorization: Bearer ...`).
- For repeated calls in scripts, wrap in a bash function that takes `(method, json_data)` and appends `"$ADDR" "$method"` last — cleaner than templating the address inline.
- Response JSON uses **camelCase** field names (proto3 JSON mapping), not the snake_case from the `.proto` file. `doc_id` in the proto becomes `docId` in the output. If jq returns `null` for a field you're sure is set, this is almost always why — alias it: `jq '{doc_id: .docId, text_score: .textScore}'`.
- Proto `oneof` fields must use the **wrapped field name** in JSON, not a shortened alias. `RankFieldSelection.vector_search_field` (not `vector_search`). grpcurl reports "message type X has no known field named Y" when you guess wrong — grep the `.proto` for the exact field name before inventing one.
- `google.protobuf.Value` accepts a JSON list directly for ListValue (e.g. a vector passed as `{"type": "FLOATS", "value": [1.0, 0.0, 0.0]}`). The enclosing FieldType must match the declared enum — DDVector uses `FLOATS` for vectors, not `VECTOR` (which doesn't exist).

## stat portability

- `stat -f %m file` (BSD/macOS default) vs `stat -c %Y file` (GNU coreutils) — incompatible. On macOS with Homebrew coreutils in PATH, `-f` means `--file-system` and dumps filesystem info. Use `date -r file +%s` instead: portable across BSD and GNU for "file mtime as unix seconds."

## tree-sitter (smacker/go-tree-sitter)

- Parenthesized Go declaration blocks (`var (...)`, `const (...)`, `type (...)`) wrap their specs in a `*_spec_list` intermediate node. A walker that just iterates `decl.NamedChild(i)` looking for `var_spec` will miss all grouped declarations. Always unwrap the `_list` wrapper.
- Python `async def` appears as a `function_definition` with an unnamed `async` keyword child. Detect via `n.Child(i).Type() == "async"` across all children (including unnamed), not via a separate node type.
- Java `formal_parameter` and `spread_parameter` both have a `type` field — use `ChildByFieldName("type")` uniformly, and append `...` only when the node type is `spread_parameter`.
- Tree-sitter `Point.Row` is 0-indexed. Git line numbers are 1-indexed. Always `+1` when converting for user-facing output or comparison with git hunk ranges.

## gh CLI PR review drafts

- To post a **pending/draft PR review** with line comments: `POST /repos/:o/:r/pulls/:n/reviews` with a JSON body containing `commit_id`, `body`, and `comments[]` — and **omit the `event` field**. Setting `"event": "COMMENT"` (or APPROVE / REQUEST_CHANGES) submits immediately. No-event = pending state, editable in the UI, invisible to others until submitted.
- Line comments: use `line` + `side: "RIGHT"` (post-change side). Simpler than computing `position` from the diff hunk header. Use `start_line` + `line` for multi-line ranges.

## Datadog MCP dashboard authoring

- **Verify metric names before using them.** The Datadog metrics API surface is large and many plausible names (`postgresql.heap_blocks_hit_ratio`, `p95:postgresql.queries.duration`, `dd.postgres.client.wait_duration_ms`, `system.io.r_s`, `container.io.read.bytes`, `container.io.write.bytes`) do not actually exist. Use `mcp__datadog__search_datadog_metrics` or inspect a real existing dashboard (`mcp__datadog__get_datadog_dashboard` on a known working dashboard ID) to confirm names before writing widget queries. Verified container disk metrics: `container.io.read` and `container.io.write` (no `.bytes` suffix); `container.io.read.operations` and `container.io.write.operations` for IOPS.
- **`.as_count()` / `.as_rate()` placement**: must come after `by {tags}`, not before. `sum:metric{filter} by {group}.as_count()` is correct; `sum:metric{filter}.as_count() by {group}` is wrong and will fail.
- **`system.io.await` cannot be scoped by `postgres_cluster` tag** — it's host-level, not container-level. Filter it only by `datacenter` or `kube_cluster_name`; the `postgres_cluster` tag is not applied to it.
- **Prefer naming-convention filters over team tags for auto-discovery.** `postgres_cluster:*-embeddings-db` catches all clusters matching the naming pattern, including ones under legacy team names (e.g. `bits-ai`). A `team:` tag filter silently misses clusters that predate the current team name. When building dashboards meant to auto-discover infrastructure, use the resource name pattern, not the team tag.
- **Wildcard tag values work in Datadog metric queries**: `postgres_cluster:*-embeddings-db` is valid filter syntax and matches all tag values ending in `-embeddings-db`.

## Claude CLI headless invocation

- **`--print` buffers all output until exit** — no streaming. For live output use `--output-format stream-json --verbose`, then parse the JSON events on stdout.
- **`stream-json` event types**: `assistant` (model text + tool calls), `result` (final, has `subtype=error` on failure), `system`/hooks (skip). Extract `message.content[].text` and `message.content[].type=="tool_use"` for meaningful display.
- **Prompt via stdin, not positional arg** — passing the prompt as a positional arg fails with "Input must be provided through stdin" when another claude session is active. Write to stdin and close: `stdin:write(prompt, function() stdin:shutdown(function() stdin:close() end) end)`.
- **`--no-session-persistence`** — always add this for headless invocations to avoid polluting the user's session history.
- **Tool allowlist** — use `--allowedTools` to lock down what the headless agent can do. Enumerate exact subcommands (`Bash(git show *)`, not `Bash(git *)`), exact script paths for interpreters (`Bash(python3 /path/to/script.py *)`), not broad wildcards.

## Neovim plugin testing (nvim --headless)

- **No luarocks/busted needed** — use `nvim --headless -u tests/minimal_init.lua -c "luafile tests/spec.lua" -c "qa!"`. Zero dependencies beyond Neovim itself.
- **minimal_init.lua is one line**: `vim.opt.runtimepath:prepend(vim.fn.getcwd())` — this makes `require("your_plugin")` work from the repo root.
- **Exit code**: call `os.exit(1)` (not `vim.cmd("cquit 1")`) in the test summary on failure — `cquit` is less reliable in headless mode.
- **getqflist filename**: `vim.fn.getqflist()` entries have `bufnr`, not `filename`. Retrieve the path with `vim.api.nvim_buf_get_name(entry.bufnr)` in tests.
- **Makefile loop**: `for f in tests/0*_spec.lua; do nvim --headless -u tests/minimal_init.lua -c "luafile $$f" -c "qa!" 2>&1 || exit 1; done` runs all specs in order.
- **vim.schedule in headless**: replace with a direct call `vim.schedule = function(fn) fn() end` in tests to make async callbacks synchronous.

## Neovim async pipe streaming (vim.uv)

- **`read_start` delivers chunks, not lines** — a single callback can contain multiple lines or a partial line. Carry a `partial` string across callbacks; only flush complete lines (split on `\n`, keep the last element as the new `partial`).
- **`nvim_buf_set_option` is deprecated in nvim 0.12+** — use `vim.bo[bufnr].option = value` instead.
- **Always leave a trailing blank line** in a streaming buffer so the next `set_lines(lc-1, lc, ...)` call has somewhere to replace into without off-by-one errors.

## Neovim Lua + JSON

- **`vim.json.decode` produces `vim.NIL` (a userdata sentinel) for JSON `null`, and `vim.NIL` is TRUTHY in Lua.** So `local x = obj.field or default` does NOT fall through when `field` is null — it returns `vim.NIL`, then any subsequent comparison (`x >= 1`, `x == nil`) raises "attempt to compare number with userdata" or behaves wrongly. Defensively coerce at the boundary: `local function num_or_nil(v) return type(v) == "number" and v or nil end` then `local n = num_or_nil(obj.field) or default`. Common offenders: GitHub PR review comments where `line: null` for outdated diff positions, and any optional field in REST/GraphQL responses.
- **Treesitter does NOT highlight virt_lines content** — the `hl_group` you pass in each chunk segment is final. If virt_lines render in unexpected colors, the cause is almost always that your highlight group got redefined (by a colorscheme loading after your plugin), not Treesitter override. Fix by registering the highlight at module load AND on `ColorScheme` events, wrapping the latter in `vim.schedule` so it runs after the theme finishes its own `nvim_set_hl` calls.
- **Lua patterns operate on bytes, not codepoints.** `─+` (or any other UTF-8 box-drawing/emoji character followed by `+`) appears to work because the byte sequence happens to repeat cleanly, but you're matching "one-or-more of these exact 3 bytes" — fragile if the sequence ever appears partial or is interleaved. To assert "this string is a run of `─` chars," use `s:gsub("─", "") == ""` instead of regex. Same for any multi-byte char in any pattern.
- **`nvim_buf_set_lines` rejects ANY string containing `\n` or `\r`** — even if you meant the `\n` to be a literal escape. `string.format("%q", body)` does NOT save you: if `body` already contains real newline bytes, `%q` preserves them. Always pre-strip with `gsub("[\r\n]+", " ")` (or split into multiple lines) before passing to `nvim_buf_set_lines`. Common trap: dumping JSON-decoded review-comment bodies to a scratch buffer.

## Long-Term Memory

A Stop hook (`hooks/save_hook.sh`) fires every ~100 human messages to remind you to persist knowledge. Two storage tiers:

- **Memory system** (`memory/` files): Project-specific and personal context — user preferences, feedback, project decisions, external references. Use the auto-memory types (user, feedback, project, reference).
- **CLAUDE.md** (this file): Universal rules, tips, and patterns that apply to ALL future sessions across any project. Add new sections here when you discover reusable knowledge (syntax gotchas, tool idioms, workflow patterns).
