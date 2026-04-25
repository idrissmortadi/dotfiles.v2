#!/bin/bash
# Gather PR context for the current branch using GitHub CLI

set -e

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$CURRENT_BRANCH" ]; then
    echo "Not in a git repository or in detached HEAD state"
    exit 0
fi

# Check if gh is available
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) not installed - skipping PR context"
    exit 0
fi

# Check if we're in a GitHub repo
if ! gh repo view >/dev/null 2>&1; then
    echo "Not a GitHub repository or not authenticated - skipping PR context"
    exit 0
fi

echo "=== PR FOR CURRENT BRANCH ==="
PR_INFO=$(gh pr view --json number,title,state,url,reviewDecision,reviewRequests,labels,isDraft 2>/dev/null || echo "")
if [ -n "$PR_INFO" ]; then
    echo "$PR_INFO" | jq -r '"PR #\(.number): \(.title)"'
    echo "$PR_INFO" | jq -r '"State: \(.state)\(if .isDraft then " (DRAFT)" else "" end)"'
    echo "$PR_INFO" | jq -r '"URL: \(.url)"'
    echo "$PR_INFO" | jq -r 'if .reviewDecision then "Review: \(.reviewDecision)" else "Review: PENDING" end'
    LABELS=$(echo "$PR_INFO" | jq -r '.labels[].name' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
    if [ -n "$LABELS" ]; then
        echo "Labels: $LABELS"
    fi
else
    echo "No PR found for branch: $CURRENT_BRANCH"
fi

echo ""
echo "=== PR CHECKS STATUS ==="
gh pr checks 2>/dev/null || echo "No checks available"

echo ""
echo "=== PR COMMENTS (last 5) ==="
gh pr view --comments --json comments 2>/dev/null | jq -r '.comments[-5:][] | "[\(.author.login)] \(.body | split("\n")[0])"' 2>/dev/null || echo "No comments"
