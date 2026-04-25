---
name: pr-describe
description: Generate and update PR descriptions with summary, context, and checklist. Use when creating or updating pull request descriptions, or when user asks to describe/document a PR.
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

Generate comprehensive PR descriptions following the project's template standards.

## Dynamic Context

**Current Branch:**
!`git branch --show-current`

**Git Remote:**
!`git remote get-url origin`

**Recent Commits:**
!`git log origin/main..HEAD --oneline --no-decorate`

## Instructions

### Step 1: Validate Context

1. Check if current branch is `main` or `master`
   - If yes, STOP and inform user they cannot update PR from main branch
   - Ask them to switch to their feature branch

### Step 2: Fetch PR Information

1. **Determine PR target:**
   - If `$ARGUMENTS` provided: Use that PR number/URL as `<pr-ref>`
   - If no arguments: Use current branch (no `<pr-ref>` needed)

2. **Fetch PR data using simple commands:**

   ```bash
   # Get PR metadata
   gh pr view <pr-ref> --json number,title,url,baseRefName,headRefName,body

   # Get PR diff
   gh pr diff <pr-ref>

   # Get changed files
   gh pr diff <pr-ref> --name-only
   ```

   - Omit `<pr-ref>` if no arguments provided (uses current branch)
   - If commands fail, inform user no PR found

### Step 3: Gather Context

1. **Repository Check:**
   - Extract repository from PR URL or git remote (from dynamic context)
   - Determine if working directory matches PR repository
   - If repositories match: Proceed to read changed files
   - If repositories differ: Skip file reading, use only diff context

2. **Read Changed Files (if same repo):**
   - Read up to 5 most relevant changed files for context
   - Focus on files that explain the "why" of changes (new features, bug fixes)
   - Look for related test files to understand test coverage

3. **Identify JIRA Ticket:**
   - Check branch name for JIRA ticket pattern (e.g., `AIPSTO-123`)
   - Check existing PR title for ticket pattern
   - Check recent commit messages for ticket pattern
   - If not found, ask user for JIRA ticket ID

### Step 4: Generate PR Content

#### PR Title Format

```
[JIRA-TICKET] Component/Service: Concise description of change
```

Examples:

- `[AIPSTO-123] docstore_go: Add datacenter override support`
- `[AIPSTO-456] advisory-lock: Fix nil pointer panic in resolveFieldInfo`
- `[APPSEC-789] CLI: Add generate-all command for concurrent execution`

**Title Guidelines:**

- Keep under 72 characters
- Start with JIRA ticket in brackets
- Follow with component/service name
- Use imperative mood ("Add", "Fix", "Update", not "Added", "Fixed", "Updated")
- Be specific but concise

#### PR Body Template

```markdown
## Summary

[2-3 sentences describing the change, its impact, and the solution approach]

## Changes

- [Key change 1]
- [Key change 2]
- [Key change 3]

## Testing

[Describe how the changes were tested - unit tests, integration tests, manual testing, staging, test drives...]
```

**For Bug Fixes, also include:**

```markdown
## Bug Details

**Environment:** [staging/production/local]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Root Cause:**
[Brief explanation of what caused the bug]

**Solution:**
[How this PR fixes the issue]
```

**Content Guidelines:**

- **Summary:** Focus on the "why" and "what", not implementation details
- **Changes:** List functional changes, not code changes
- **Testing:** Be specific about test coverage and validation approach
- **Adapt template:** Remove irrelevant sections, add sections as needed

### Step 5: Update PR

1. **Generate Title:**
   - Extract JIRA ticket from branch/commits
   - Analyze changes to determine component/service
   - Create concise, imperative description

2. **Generate Body:**
   - Write compelling summary (2-3 sentences)
   - List key changes as bullet points
   - Describe testing approach
   - Check relevant checklist items based on changes
   - Add bug section if this is a bug fix

3. **Update PR using gh CLI:**

   ```bash
   gh pr edit <number|url> --title "New Title" --body "$(cat <<'EOF'
   [PR body content here]
   EOF
   )"
   ```

4. **Confirm Success:**
   - Show the user the updated title and body
   - Provide link to view PR in browser

## Notes

- Always read changed files to understand context (when in same repo)
- Look for related documentation or test files
- Consider the type of change (feature/bug/refactor) when writing description
- Use specific command examples in testing section
- Be concise but comprehensive
- Match the tone and style of existing PRs in the repository
- If you cannot determine certain information, use placeholders and ask user for input

## Examples

**Feature PR:**

```
[AIPSTO-327] docstore_go: Add datacenter override support

## Summary

Adds support for datacenter override configuration in docstore_go to allow services to explicitly specify their target datacenter. This enables better control over data locality and compliance requirements.

## Changes

- Added `datacenter` field to store configuration
- Implemented datacenter resolution logic with environment variable fallback
- Added validation for supported datacenter values

## Testing

- Added unit tests for datacenter resolution logic
- Tested with multiple datacenter configurations in staging
- Verified fallback behavior when datacenter not specified
```

**Bug Fix PR:**

```
[AIPSTO-332] advisory-lock: Fix nil pointer panic in resolveFieldInfo

## Summary

Fixes a nil pointer dereference in resolveFieldInfo that caused service crashes when processing certain field types. The issue occurred when field metadata was missing from the schema definition.

## Bug Details

**Environment:** Production

**Steps to Reproduce:**
1. Send request with field type not in schema
2. Service attempts to resolve field info
3. Panic occurs due to nil pointer dereference

**Root Cause:**
The code assumed all field types would have metadata entries, but certain dynamic field types were not pre-populated in the schema map.

**Solution:**
Added nil checks before dereferencing field metadata and implemented graceful fallback to default field handling.

## Changes

- Added nil pointer checks in resolveFieldInfo
- Implemented default field handling for unknown types
- Added defensive logging for debugging

## Testing

- Added unit tests covering nil metadata scenarios
- Verified fix in staging with problematic payloads
- Added integration test for edge cases
```
