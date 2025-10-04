#!/bin/bash

SINCE="2025-09-03T00:00:00Z"
INPUT="candidates_raw.jsonl"
OUTPUT="hydrated.jsonl"
> "$OUTPUT"

# Get unique logins
LOGINS=$(jq -r .login "$INPUT" | sort -u)
TOTAL=$(echo "$LOGINS" | wc -l)

COUNT=0
for LOGIN in $LOGINS; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT/$TOTAL] Hydrating $LOGIN"

  # Get user profile with all signals
  gh api graphql -f query='
    query($login: String!, $from: DateTime!) {
      user(login: $login) {
        login
        name
        bio
        company
        location
        followers { totalCount }
        isHireable
        isEmployee
        repositories(isFork: false, privacy: PUBLIC, first: 50, orderBy: {field: STARGAZERS, direction: DESC}) {
          totalCount
          nodes {
            name
            stargazerCount
            primaryLanguage { name }
          }
        }
        pullRequests(states: MERGED, first: 50, orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes {
            mergedAt
            repository {
              stargazerCount
              nameWithOwner
            }
            reviews { totalCount }
          }
        }
        contributionsCollection(from: $from) {
          totalCommitContributions
          pullRequestReviewContributions(first: 100) { totalCount }
        }
        sponsorshipsAsMaintainer(first: 1) { totalCount }
      }
    }
  ' -f login="$LOGIN" -f from="$SINCE" 2>/dev/null | \
    jq -c '.data.user' >> "$OUTPUT" 2>/dev/null

  # Rate limit pause
  if [ $((COUNT % 20)) -eq 0 ]; then
    echo "  (pausing to respect rate limits...)"
    sleep 2
  fi
done

echo ""
echo "Hydrated $(wc -l < "$OUTPUT") profiles"
