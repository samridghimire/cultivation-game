#!/usr/bin/env bash
# Deletes remote claude/* claim branches that are no longer needed:
#   - the task already landed on main (a commit subject starts with "[<task-id>]"), or
#   - the newest commit on the branch is older than MAX_AGE_HOURS and the branch is a claim
#     (its first commit above main is "claim <id>"), i.e. an abandoned claim. Other old
#     claude/* work branches are kept.
# Cloud agents can't delete branches (the git proxy returns 403), so the hourly GitHub
# Action in .github/workflows/cleanup-claims.yml runs this. Safe to run by hand too.
set -euo pipefail
MAX_AGE_HOURS="${MAX_AGE_HOURS:-4}"
DRY_RUN="${DRY_RUN:-0}"

git fetch --quiet --prune origin
now=$(date +%s)
landed=$(git log origin/main --format=%s -n 3000 | grep -oE '^\[[A-Za-z0-9-]+\]' | tr -d '[]' | sort -u || true)

for ref in $(git for-each-ref --format='%(refname:strip=4)' refs/remotes/origin/claude/); do
  branch="claude/${ref}"
  # Branch names are <task-id>-<slug>; the task landed if some landed id is a prefix of the name.
  task_id=""
  while read -r id; do
    [[ -n "$id" && "$ref" == "$id-"* && ${#id} -gt ${#task_id} ]] && task_id="$id"
  done <<< "$landed"
  age_h=$(( (now - $(git log -1 --format=%ct "origin/$branch")) / 3600 ))
  reason=""
  if [[ -n "$task_id" ]]; then
    reason="landed ($task_id on main)"
  elif (( age_h >= MAX_AGE_HOURS )); then
    first=$(git log --reverse --format=%s "origin/main..origin/$branch" | head -n 1)
    if [[ "$first" == claim\ * ]]; then
      reason="stale claim (${age_h}h old)"
    else
      echo "keep   $branch (${age_h}h old, not a claim branch)"
      continue
    fi
  fi
  if [[ -n "$reason" ]]; then
    echo "delete $branch: $reason"
    if [[ "$DRY_RUN" != "1" ]]; then
      git push --quiet origin --delete "$branch" || echo "  failed to delete $branch, continuing"
    fi
  else
    echo "keep   $branch (${age_h}h old, active claim)"
  fi
done
