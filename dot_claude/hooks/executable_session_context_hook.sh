#!/bin/bash
set -eo pipefail

# SESSION CONTEXT HOOK — Load branch, PR, and working tree context at session start
#
# Fires on SessionStart (startup, clear, compact). Outputs context to stdout
# which Claude Code injects into the conversation.
#
# On a feature branch: loads PR description, diff, comments, git status, local diff.
# On main/master or no git: outputs minimal info.

DIFF_LINE_CAP=500
PR_COMMENTS_CAP=100

# Parse input
INPUT=$(cat)
CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)

[ -z "$CWD" ] && exit 0
cd "$CWD" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BRANCH=$(git branch --show-current 2>/dev/null)

# Determine base branch:
# 1. If a PR exists, use its base ref (handles stacked branches)
# 2. Fall back to main/master
BASE=""
if [ -n "$BRANCH" ] && command -v gh >/dev/null 2>&1; then
  BASE=$(gh pr view --json baseRefName -q '.baseRefName' 2>/dev/null || true)
fi
if [ -z "$BASE" ]; then
  if git rev-parse --verify main >/dev/null 2>&1; then
    BASE=main
  elif git rev-parse --verify master >/dev/null 2>&1; then
    BASE=master
  fi
fi

# -------------------------------------------------------------------
# Git status & local (uncommitted) diff — always shown
# -------------------------------------------------------------------
echo "=== Working Tree ==="
echo "Branch: ${BRANCH:-detached HEAD}"
echo ""

STATUS=$(git status --short 2>/dev/null)
if [ -n "$STATUS" ]; then
  echo "Git status:"
  echo "$STATUS"
  echo ""

  LOCAL_DIFF=$(git diff 2>/dev/null)
  STAGED_DIFF=$(git diff --cached 2>/dev/null)
  COMBINED_DIFF=""
  [ -n "$STAGED_DIFF" ] && COMBINED_DIFF="$STAGED_DIFF"
  if [ -n "$LOCAL_DIFF" ]; then
    [ -n "$COMBINED_DIFF" ] && COMBINED_DIFF="$COMBINED_DIFF"$'\n'"$LOCAL_DIFF" || COMBINED_DIFF="$LOCAL_DIFF"
  fi

  if [ -n "$COMBINED_DIFF" ]; then
    LOCAL_LINES=$(wc -l <<<"$COMBINED_DIFF" | tr -d ' ')
    echo "Local diff (staged + unstaged, ${LOCAL_LINES} lines):"
    if [ "$LOCAL_LINES" -gt "$DIFF_LINE_CAP" ]; then
      head -n "$DIFF_LINE_CAP" <<<"$COMBINED_DIFF"
      echo "... ($((LOCAL_LINES - DIFF_LINE_CAP)) lines omitted)"
    else
      echo "$COMBINED_DIFF"
    fi
    echo ""
  fi
else
  echo "Working tree clean."
  echo ""
fi

# -------------------------------------------------------------------
# If on base branch (or no base), stop here
# -------------------------------------------------------------------
if [ -z "$BRANCH" ] || [ -z "$BASE" ] || [ "$BRANCH" = "$BASE" ]; then
  exit 0
fi

# Make sure the base ref is available locally for diffing
if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  git fetch origin "$BASE" >/dev/null 2>&1 || exit 0
  BASE="origin/$BASE"
fi

# -------------------------------------------------------------------
# Branch diff against base
# -------------------------------------------------------------------
EXCLUDES=(
  ':(exclude)*.pb.go'
  ':(exclude)*_pb2.py'
  ':(exclude)*_pb2.pyi'
  ':(exclude)*_pb2_grpc.py'
  ':(exclude)*_pb2_grpc.pyi'
  ':(exclude)*.mockgen.go'
  ':(exclude)*.snap'
  ':(exclude)*.swagger.json'
  ':(exclude)go.sum'
  ':(exclude)Cargo.lock'
  ':(exclude)maven_install.json'
  ':(exclude)package-lock.json'
  ':(exclude)yarn.lock'
)

echo "=== Branch Context (${BRANCH} vs ${BASE}) ==="
echo ""

COMMITS=$(git log --format="%h %s" "$BASE"..HEAD 2>/dev/null)
if [ -n "$COMMITS" ]; then
  echo "Commits:"
  echo "$COMMITS"
  echo ""

  echo "Changed files:"
  git diff "$BASE"...HEAD --stat 2>/dev/null
  echo ""

  RAW_DIFF=$(git diff "$BASE"...HEAD \
    --find-renames \
    --diff-filter=d \
    -- "${EXCLUDES[@]}" \
    2>/dev/null)

  DIFF_LINES=$(wc -l <<<"$RAW_DIFF" | tr -d ' ')
  FILES_CHANGED=$(grep -c '^diff --git' <<<"$RAW_DIFF" || true)

  echo "Diff ($FILES_CHANGED files, generated files excluded):"
  if [ "$DIFF_LINES" -gt "$DIFF_LINE_CAP" ]; then
    head -n "$DIFF_LINE_CAP" <<<"$RAW_DIFF"
    echo "... ($((DIFF_LINES - DIFF_LINE_CAP)) lines omitted, diff exceeded ${DIFF_LINE_CAP}-line cap)"
  else
    echo "$RAW_DIFF"
  fi
  echo ""
fi

# -------------------------------------------------------------------
# PR context (requires gh CLI and a GitHub remote)
# -------------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  exit 0
fi
if ! gh repo view >/dev/null 2>&1; then
  exit 0
fi

PR_JSON=$(gh pr view --json number,title,state,url,isDraft,reviewDecision,body 2>/dev/null || true)
[ -z "$PR_JSON" ] && exit 0

echo "=== PR Context ==="
echo "$PR_JSON" | python3 -c "
import sys, json
pr = json.load(sys.stdin)
status = pr['state']
if pr.get('isDraft'):
    status += ' DRAFT'
review = pr.get('reviewDecision', '')
print(f\"#{pr['number']}: {pr['title']} [{status}]\")
print(f\"URL: {pr['url']}\")
if review:
    print(f\"Review: {review}\")
print()
body = pr.get('body', '') or ''
if body.strip():
    print('Description:')
    print(body[:3000])
    if len(body) > 3000:
        print('... (truncated)')
    print()
" 2>/dev/null

# Fetch review comments (code review threads)
PR_NUMBER=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['number'])" 2>/dev/null)
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true)

if [ -n "$PR_NUMBER" ] && [ -n "$REPO" ]; then
  # Get review threads via GraphQL
  REVIEW_THREADS=$(gh api graphql -f query='
    query($owner: String!, $repo: String!, $pr: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $pr) {
          reviewThreads(first: 50) {
            nodes {
              isResolved
              path
              line
              comments(first: 10) {
                nodes {
                  author { login }
                  body
                  createdAt
                }
              }
            }
          }
        }
      }
    }
  ' -f owner="${REPO%%/*}" -f repo="${REPO##*/}" -F pr="$PR_NUMBER" 2>/dev/null || true)

  if [ -n "$REVIEW_THREADS" ]; then
    COMMENT_OUTPUT=$(echo "$REVIEW_THREADS" | python3 -c "
import sys, json

data = json.load(sys.stdin)
threads = data.get('data', {}).get('repository', {}).get('pullRequest', {}).get('reviewThreads', {}).get('nodes', [])

if not threads:
    sys.exit(0)

unresolved = [t for t in threads if not t.get('isResolved')]
resolved = [t for t in threads if t.get('isResolved')]

lines = []
cap = ${PR_COMMENTS_CAP}

def format_thread(t, count):
    out = []
    path = t.get('path', '?')
    line = t.get('line', '?')
    out.append(f'  {path}:{line}')
    for c in t.get('comments', {}).get('nodes', [])[:5]:
        author = c.get('author', {}).get('login', '?')
        body = c.get('body', '').strip()
        if len(body) > 500:
            body = body[:500] + '...'
        out.append(f'    @{author}: {body}')
    return out

if unresolved:
    lines.append(f'Unresolved comments ({len(unresolved)}):')
    for t in unresolved:
        if len(lines) > cap:
            lines.append(f'  ... ({len(unresolved)} total, output capped)')
            break
        lines.extend(format_thread(t, len(lines)))
    lines.append('')

if resolved:
    lines.append(f'Resolved comments ({len(resolved)}):')
    for t in resolved:
        if len(lines) > cap * 2:
            lines.append(f'  ... ({len(resolved)} total, output capped)')
            break
        lines.extend(format_thread(t, len(lines)))
    lines.append('')

print('\n'.join(lines))
" 2>/dev/null || true)

    if [ -n "$COMMENT_OUTPUT" ]; then
      echo ""
      echo "Review comments:"
      echo "$COMMENT_OUTPUT"
    fi
  fi

  # Also get issue-style PR comments (conversation tab)
  PR_COMMENTS=$(gh pr view "$PR_NUMBER" --json comments -q '.comments[] | "  @\(.author.login): \(.body)"' 2>/dev/null | head -n "$PR_COMMENTS_CAP" || true)
  if [ -n "$PR_COMMENTS" ]; then
    echo ""
    echo "PR conversation comments:"
    echo "$PR_COMMENTS"
  fi
fi

exit 0
