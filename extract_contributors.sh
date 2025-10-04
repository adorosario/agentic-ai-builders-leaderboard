#!/bin/bash

SINCE="2025-09-03T00:00:00Z"
OUTPUT="candidates_raw.jsonl"
> "$OUTPUT"

COUNT=0
while IFS= read -r REPO; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT] $REPO"

  OWNER=$(echo "$REPO" | cut -d/ -f1)
  NAME=$(echo "$REPO" | cut -d/ -f2)

  RESULT=$(gh api graphql -f query='query($owner:String!, $name:String!, $since:DateTime!){ repository(owner:$owner, name:$name){ pullRequests(states:MERGED, orderBy:{field:UPDATED_AT, direction:DESC}, first:100){ nodes{ mergedAt author{login}}}}}' \
    -F owner="$OWNER" \
    -F name="$NAME" \
    -F since="$SINCE" 2>/dev/null)

  if [ ! -z "$RESULT" ]; then
    echo "$RESULT" | jq -c --arg SINCE "$SINCE" --arg REPO "$REPO" \
      '.data.repository.pullRequests.nodes // [] | map(select(.mergedAt >= $SINCE and .author.login != null)) | map({login:.author.login, mergedAt, repo:$REPO}) | .[]' \
      >> "$OUTPUT" 2>/dev/null
  fi
done < <(jq -r '.fullName' agentic_seed.jsonl | head -50)

echo ""
echo "Total contributors: $(jq -r .login "$OUTPUT" | sort -u | wc -l)"
