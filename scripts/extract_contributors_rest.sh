#!/bin/bash

SINCE="2025-09-03T00:00:00Z"
OUTPUT="candidates_raw.jsonl"
> "$OUTPUT"

COUNT=0
while IFS= read -r REPO; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT] $REPO"

  # Get merged PRs since SINCE date
  gh api "repos/$REPO/pulls?state=closed&per_page=100&sort=updated&direction=desc" 2>/dev/null | \
    jq -c --arg SINCE "$SINCE" --arg REPO "$REPO" \
      '.[] | select(.merged_at != null and .merged_at >= $SINCE) | {login: .user.login, merged_at: .merged_at, repo: $REPO}' \
      >> "$OUTPUT" 2>/dev/null

done < <(jq -r '.fullName' agentic_seed.jsonl | head -30)

echo ""
UNIQUE=$(jq -r .login "$OUTPUT" | sort -u | wc -l)
TOTAL=$(wc -l < "$OUTPUT")
echo "Total PRs: $TOTAL"
echo "Unique contributors: $UNIQUE"
echo ""
echo "Top 10 contributors:"
jq -r .login "$OUTPUT" | sort | uniq -c | sort -rn | head -10
