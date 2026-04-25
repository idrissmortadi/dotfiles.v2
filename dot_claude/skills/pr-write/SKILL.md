---
name: pr-write
description: Generate and update PR descriptions with summary, context, and testing. Use when creating or updating pull request descriptions, or when user asks to write/document a PR.
disable-model-invocation: true
argument-hint: [pr-number|pr-url]
allowed-tools:
  - Bash(gh *)
  - Bash(git *)
  - Read
  - Grep
  - Glob
---

# PR Description Generator

Generate concise, informative PR descriptions.

## Dynamic Context

**Current Branch:**
!`git branch --show-current`

**Git Remote:**
!`git remote get-url origin`

**Recent Commits:**
!`git log origin/main..HEAD --oneline --no-decorate`

## Instructions

### Step 1: Validate Context

If current branch is `main` or `master`, STOP and tell the user to switch to their feature branch.

### Step 2: Fetch PR Information

- If `$ARGUMENTS` provided: use that PR number/URL as `<pr-ref>`
- If no arguments: use current branch (omit `<pr-ref>`)

```bash
gh pr view <pr-ref> --json number,title,url,baseRefName,headRefName,body
gh pr diff <pr-ref> --name-only
gh pr diff <pr-ref>
```

If commands fail, inform user no PR found.

### Step 3: Gather Context

1. If working directory matches PR repo: read up to 5 most relevant changed files (focus on files that explain the "why")
2. Otherwise: use diff context only
3. **Find JIRA ticket:** check branch name → PR title → commit messages → ask user if not found

### Step 4: Generate PR Content

#### Title

```
[JIRA-TICKET] Component/Service: Concise description
```

- Under 72 characters
- Imperative mood: "Add", "Fix", "Update" (not past tense)
- Examples:
  - `[AIPSTO-123] docstore_go: Add datacenter override support`
  - `[AIPSTO-456] advisory-lock: Fix nil pointer panic in resolveFieldInfo`

#### Body — Feature / Refactor

```markdown
## Summary

[2-3 sentences: what changed, why, and how]

## Changes

- [Functional change 1]
- [Functional change 2]

## Testing

[How it was tested — unit tests, staging, test drives, manual steps]
```

#### Body — Bug Fix (add this section)

```markdown
## Bug

**Root cause:** [what caused it]
**Fix:** [how this PR resolves it]
**Repro:** [brief steps, environment if relevant]
```

**Guidelines:**
- Summary: the "why" and "what", not implementation details
- Changes: functional changes, not code-level changes
- Testing: be specific — name the test, environment, or command
- Omit sections that don't apply

### Step 5: Update PR

```bash
gh pr edit <number|url> --title "..." --body "$(cat <<'EOF'
[body here]
EOF
)"
```

Show the user the updated title and body, and link to the PR.

## Examples

**Feature:**
```
[AIPSTO-327] docstore_go: Add datacenter override support

## Summary

Adds datacenter override support to docstore_go so services can explicitly
target a specific datacenter. Enables better data locality control and
compliance enforcement at the service level.

## Changes

- Added `datacenter` field to store configuration
- Implemented resolution logic with env var fallback
- Added validation for supported datacenter values

## Testing

- Unit tests for resolution logic and fallback behavior
- Verified with multiple datacenter configs in staging
```

**Bug fix:**
```
[AIPSTO-332] advisory-lock: Fix nil pointer panic in resolveFieldInfo

## Summary

Fixes a nil pointer dereference in resolveFieldInfo that crashed the service
when processing field types missing from the schema. Added nil checks and
graceful fallback to default field handling.

## Changes

- Added nil checks before dereferencing field metadata
- Implemented default handling for unknown field types

## Testing

- Unit tests covering nil metadata scenarios
- Verified fix in staging with previously crashing payloads

## Bug

**Root cause:** Code assumed all field types had metadata entries; dynamic
types were not pre-populated in the schema map.
**Fix:** Nil guard + fallback to default field handling.
**Repro:** Send a request with a field type absent from the schema → panic.
```
