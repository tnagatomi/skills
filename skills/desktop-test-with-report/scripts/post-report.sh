#!/usr/bin/env bash
# Post a desktop-test report (a markdown file) as a comment on a pull request.
#
# Text-only fallback for the desktop-test-with-report skill. Use this when the
# report has no screenshots (e.g. a skip report) or when the browser isn't
# signed in to GitHub. To embed screenshots inline, post through agent-browser
# instead (see SKILL.md step 8) — gh cannot upload images to a comment.
#
# Usage:
#   post-report.sh <report.md> [pr]
#
#   <report.md>  Path to the markdown report to post.
#   [pr]         PR number, URL, or branch. Defaults to the PR for the
#                current branch (resolved by gh).
#
# Requires the GitHub CLI (gh), authenticated for the target repository.
set -euo pipefail

report="${1:-}"
pr="${2:-}"

if [[ -z "$report" ]]; then
  echo "usage: post-report.sh <report.md> [pr]" >&2
  exit 2
fi

if [[ ! -f "$report" ]]; then
  echo "error: report file not found: $report" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI not found. Install it from https://cli.github.com/" >&2
  exit 1
fi

# With no PR argument, `gh pr comment` targets the current branch's PR.
if [[ -n "$pr" ]]; then
  gh pr comment "$pr" --body-file "$report"
else
  gh pr comment --body-file "$report"
fi
