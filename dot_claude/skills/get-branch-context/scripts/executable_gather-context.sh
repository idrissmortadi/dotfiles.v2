#!/bin/bash
# Gather comprehensive branch context for the get-branch-context skill

set -e

# Get current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$CURRENT_BRANCH" ]; then
    echo "ERROR: Not in a git repository or in detached HEAD state"
    exit 1
fi

# Determine base branch (main or master)
if git rev-parse --verify main >/dev/null 2>&1; then
    BASE_BRANCH="main"
elif git rev-parse --verify master >/dev/null 2>&1; then
    BASE_BRANCH="master"
else
    echo "ERROR: Could not find main or master branch"
    exit 1
fi

MERGE_BASE=$(git merge-base HEAD "$BASE_BRANCH" 2>/dev/null || echo "")
BASE_HEAD=$(git rev-parse "$BASE_BRANCH" 2>/dev/null || echo "")

echo "=== BRANCH INFO ==="
echo "Current branch: $CURRENT_BRANCH"
echo "Base branch: $BASE_BRANCH"
echo "Merge base: $MERGE_BASE"
echo "Base HEAD: $BASE_HEAD"
echo ""

# Check if branch is directly on base or on intermediate branch
if [ "$MERGE_BASE" = "$BASE_HEAD" ]; then
    echo "Branch status: Directly based on $BASE_BRANCH (up to date)"
else
    echo "Branch status: Diverged from $BASE_BRANCH"
    BEHIND_COUNT=$(git rev-list --count "$MERGE_BASE".."$BASE_BRANCH" 2>/dev/null || echo "0")
    echo "Commits behind $BASE_BRANCH: $BEHIND_COUNT"
fi

echo ""
echo "=== COMMITS ON THIS BRANCH ==="
git log --oneline "$BASE_BRANCH"..HEAD 2>/dev/null || echo "(no commits ahead of $BASE_BRANCH)"

echo ""
echo "=== FILE CHANGES SUMMARY ==="
git diff "$BASE_BRANCH"...HEAD --stat 2>/dev/null || echo "(no changes)"

echo ""
echo "=== RECENT BRANCHES (for detecting intermediate branches) ==="
git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short) %(objectname:short)' --count=15 2>/dev/null || echo "(could not list branches)"

echo ""
echo "=== STASH STATUS ==="
STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
if [ "$STASH_COUNT" -gt 0 ]; then
    echo "Stashes: $STASH_COUNT"
    git stash list --format="%gd: %s" 2>/dev/null | head -5
else
    echo "No stashes"
fi

echo ""
echo "=== WORKING DIRECTORY STATUS ==="
git status --short 2>/dev/null || echo "(could not get status)"
