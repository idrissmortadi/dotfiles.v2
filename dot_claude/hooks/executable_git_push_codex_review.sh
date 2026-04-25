#!/usr/bin/env bash
# PostToolUse hook for Bash.
# After a successful `git push` inside a ~/dd/ repo on a branch with an open PR,
# posts `@codex review` and `@cursor review` as separate PR comments, then
# asks Claude to schedule a 30-minute wake-up to address review feedback.

set -u

emit_empty() { printf '{}\n'; exit 0; }

payload=$(cat)

tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // ""')
[ "$tool_name" = "Bash" ] || emit_empty

cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')
# Match `git push` (optionally `git -C <dir> push`), ignore `git push --dry-run`/help.
printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git([[:space:]]+-[^[:space:]]+[[:space:]]+[^[:space:]]+)*[[:space:]]+push([[:space:]]|$)' || emit_empty
printf '%s' "$cmd" | grep -Eq -- '--dry-run' && emit_empty

cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""')
[ -n "$cwd" ] || cwd=$(pwd)

# Resolve to real path, must live under ~/dd/.
dd_root="$HOME/dd"
case "$cwd/" in
  "$dd_root"/*) ;;
  *) emit_empty ;;
esac

# Verify push succeeded (exit 0). Missing = assume success.
exit_code=$(printf '%s' "$payload" | jq -r '.tool_response.exit_code // .tool_response.exitCode // 0')
[ "$exit_code" = "0" ] || emit_empty

cd "$cwd" 2>/dev/null || emit_empty

# Must be a git repo.
git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit_empty

branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$branch" ] && [ "$branch" != "HEAD" ] || emit_empty

# Open PR for this branch?
pr_number=$(gh pr view --json number,state -q 'select(.state=="OPEN") | .number' 2>/dev/null)
[ -n "$pr_number" ] || emit_empty

# Dedupe: only fire once per push-sha per PR.
head_sha=$(git -C "$cwd" rev-parse HEAD 2>/dev/null)
state_dir="$HOME/.claude/hooks/state/codex-review"
mkdir -p "$state_dir"
marker="$state_dir/pr-${pr_number}-${head_sha}"
if [ -f "$marker" ]; then
  emit_empty
fi

codex_ok=0
cursor_ok=0
gh pr comment "$pr_number" --body '@codex review' >/dev/null 2>&1 && codex_ok=1
gh pr comment "$pr_number" --body '@cursor review' >/dev/null 2>&1 && cursor_ok=1

if [ "$codex_ok" -eq 1 ] && [ "$cursor_ok" -eq 1 ]; then
  : > "$marker"
fi

context="Posted \`@codex review\` and \`@cursor review\` comments on PR #${pr_number} (branch \`${branch}\`) via git-push hook. Now schedule a wake-up in 30 minutes (1800 seconds) using ScheduleWakeup to run the \`dd:pr:address-feedback\` skill and address any review feedback that has arrived. Reason: \"waiting 30m for codex/cursor review on PR #${pr_number}\"."

if [ "$codex_ok" -eq 0 ] || [ "$cursor_ok" -eq 0 ]; then
  context="Attempted to post codex/cursor review comments on PR #${pr_number} but at least one failed (codex_ok=${codex_ok}, cursor_ok=${cursor_ok}). Inform the user and do NOT schedule a wake-up."
fi

jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
