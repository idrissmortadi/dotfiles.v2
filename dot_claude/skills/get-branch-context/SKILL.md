---
description: Load context of current branch and track work done back to main. Shows commits, file changes, PR status, and stacked PR context if using Graphite.
context: fork
agent: Explore
allowed-tools: Bash(git *), Bash(gh *), Bash(gt *)
---

# Branch Context

You are helping the user understand the work done on their current branch.

## Pre-fetched Git Context

### Current Branch
!`git branch --show-current`

### Merge Base with Main
!`git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo "Could not find merge base"`

### Main HEAD
!`git rev-parse main 2>/dev/null || git rev-parse master 2>/dev/null || echo "Could not find main/master"`

### Commits on This Branch
!`git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD 2>/dev/null || echo "No commits ahead"`

### File Changes Summary
!`git diff main...HEAD --stat 2>/dev/null || git diff master...HEAD --stat 2>/dev/null || echo "No changes"`

### Recent Branches (for detecting intermediate branches)
!`git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short) %(objectname:short)' --count=10`

### Working Directory Status
!`git status --short`

### Stash Status
!`git stash list --format="%gd: %s" | head -5 || echo "No stashes"`

## Pre-fetched PR Context

### PR for Current Branch
!`gh pr view --json number,title,state,url,reviewDecision,isDraft 2>/dev/null || echo "No PR found"`

### PR Checks
!`gh pr checks 2>/dev/null || echo "No checks available"`

## Pre-fetched Stack Context (Graphite)

### Stack Status
!`gt status 2>/dev/null || echo "Not using Graphite"`

### Stack Log
!`gt log --stack 2>/dev/null || echo ""`

## Your Task

Analyze the pre-fetched context above and provide:

1. **Branch Summary**
   - Current branch name and its relationship to the base branch
   - Whether the branch is up to date with base or has diverged
   - Number of commits and overall scope of changes

2. **Work Summary**
   - Concise description of what this branch accomplishes (features, fixes, refactors)
   - Key files and areas modified
   - Any notable patterns in the commits

3. **PR Status** (if applicable)
   - PR state (open, draft, merged)
   - Review status and CI/check status

4. **Stack Context** (if using Graphite)
   - Position in the stack
   - Dependencies and dependents
   - Any branches needing attention

5. **Intermediate Branches** (if not directly based on main)
   - If merge-base differs from main HEAD, identify the intermediate branch
   - Offer to trace the full chain: main -> [branch1] -> [current]

## Guidelines

- Be concise - focus on actionable information
- Highlight issues: failing CI, merge conflicts, uncommitted changes
- For stacked PRs, note if any branches need rebasing
