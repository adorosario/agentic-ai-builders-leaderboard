# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository generates a **daily leaderboard of developers actively contributing to agentic AI technology** in the last 30 days. It focuses specifically on AI agent frameworks, LLM orchestration tools, and autonomous systems like LangChain, AutoGen, Claude Agent SDK, and 200+ similar projects.

The system ranks candidates using a 100-point scoring rubric based on recent merged PRs, code reviews, followers, and hiring availability.

## Core Workflow

The system operates in 5 stages:
1. **Seed repos**: Find agentic AI repositories updated in last 30 days (LangChain, LangGraph, agent frameworks)
2. **Extract contributors**: Identify merged PR authors using GitHub REST API
3. **Hydrate profiles**: Gather rich signals (followers, repo stars, reviews, hiring status) via GraphQL
4. **Score**: Apply 100-point rubric (60 pts activity, 25 pts reputation, 15 pts availability)
5. **Export**: Generate CSV (200 entries) and Markdown (top 50) leaderboards

## Commands

### Prerequisites
```bash
# Verify required tools
gh --version        # GitHub CLI with authentication
jq --version        # JSON processor
python3 --version   # Python 3.x
```

### Key Parameters
```bash
DAYS=30                    # Time window for "cutting edge" activity
MIN_STARS=50              # Minimum stars to filter toy repos
MAX_REPOS=200             # Initial seed size
TOP_N=200                 # Final candidate pool size
```

### Date Calculation (cross-platform)
```bash
# Works on both macOS (-v) and Linux (-d)
SINCE=$(date -u -v-${DAYS}d +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -d "-${DAYS} days" +%Y-%m-%dT00:00:00Z)
```

### Run Complete Workflow

```bash
# Main orchestrator script
./scripts/run_leaderboard.sh
```

This runs the complete 5-stage workflow:
1. Discovers ~200 agentic AI repos using `gh search repos` with queries like:
   - `"agent AI" pushed:>=SINCE_DATE stars:>=20`
   - `"langchain"`, `"langgraph"`, `"LLM agent"` queries
   - Plus specific repos: anthropic-sdk, openai-python, langfuse, etc.
2. Extracts contributors via REST API (`scripts/extract_contributors_rest.sh`)
3. Hydrates profiles via GraphQL API (`scripts/hydrate_profiles.sh`)
4. Scores with 100-point rubric (`scripts/score.py`)
5. Exports CSV + Markdown (`scripts/export.py`)

**Runtime:** ~15-20 minutes
**Output:** `leaderboard.md`, `leaderboard.csv`, `leaderboard.jsonl`

## Scoring Model (100 points)

### Activity & Quality (60 pts)
- Recent merged PRs: up to 25 pts
- Code reviews: up to 15 pts
- CI pass rate: up to 10 pts (placeholder)
- Issue responsiveness: up to 10 pts (placeholder)

### Reputation (25 pts)
- Followers (log-scaled): up to 10 pts
- Stars on owned repos: up to 10 pts
- Maintainer roles: up to 5 pts (placeholder)

### Fit & Availability (15 pts)
- Hiring status (`isHireable`): up to 5 pts
- Availability keywords in bio: up to 3 pts
- Language/stack fit: neutral 10 pts (global search)

## Key GraphQL Queries

### Extract Recent Contributors
Query PRs merged since a date from a specific repo:
```graphql
query($owner:String!, $name:String!, $since:DateTime!) {
  repository(owner:$owner, name:$name) {
    pullRequests(states:MERGED, orderBy:{field:UPDATED_AT, direction:DESC}, first:100) {
      nodes {
        mergedAt
        author { login }
        commits(last:1) { nodes { commit { committedDate } } }
      }
    }
  }
}
```

### Hydrate User Profile
Comprehensive user data including activity, repos, PRs, and reviews:
```graphql
query($login:String!, $from:DateTime!) {
  user(login:$login) {
    login name bio company location
    followers { totalCount }
    isHireable isEmployee
    repositories(isFork:false, privacy:PUBLIC, first:50, orderBy:{field:STARGAZERS, direction:DESC}) {
      totalCount
      nodes { name stargazerCount primaryLanguage { name } }
    }
    pullRequests(states:MERGED, first:50, orderBy:{field:UPDATED_AT, direction:DESC}) {
      nodes {
        mergedAt
        repository { stargazerCount nameWithOwner }
        reviews { totalCount }
      }
    }
    contributionsCollection(from:$from) {
      totalCommitContributions
      pullRequestReviewContributions(first:100) { totalCount }
    }
    sponsorshipsAsMaintainer(first:1) { totalCount }
  }
}
```

## Automation with Claude Agent SDK

The repository includes a TypeScript agent specification in `docs/claude_agent_sdk_spec_automated_cutting_edge_git_hub_builder_leaderboard.md`. The agent provides:

### Tools
- `seedRepos`: Find repos with recent activity/releases
- `recentContributors`: Extract PR authors from repos
- `hydrateUser`: Fetch comprehensive user profile
- `scoreUsers`: Apply 100-point rubric

### Main Task
`buildLeaderboard`: Orchestrates end-to-end workflow and writes artifacts

### Outputs
- `leaderboard.jsonl`: Full scored dataset
- `leaderboard.csv`: Tabular format for spreadsheets
- `leaderboard.md`: Top 50 formatted for GitHub

## GitHub Actions Integration

Schedule daily runs with:
```yaml
on:
  schedule:
    - cron: "17 3 * * *"   # Daily at 03:17 UTC
  workflow_dispatch: {}
```

Agent workflow:
1. Install dependencies (`gh`, `jq`, `python3`)
2. Authenticate with `GITHUB_TOKEN`
3. Run agent to generate leaderboard
4. Commit artifacts back to repo

## Architecture Notes

- **Data sources**: GitHub GraphQL API, REST API (releases), optional GH Archive (BigQuery) for scale
- **Rate limits**: Authenticated GraphQL provides generous limits; batch queries and paginate
- **Signal quality**: Stars/commits are noisy; prioritize merged PRs and reviews
- **"Cutting edge" definition**: Contributors to repos created OR actively released/updated within the time window
- **Availability signals**: `isHireable` field + bio keyword matching (freelance, available, consult, contract)

## Extensions & Future Improvements

- Add Checks API to compute CI pass rate on PRs
- Pull issues data for responsiveness metrics
- Pre-filter using GH Archive (BigQuery) to scale to 10k+ candidates
- Maintain blocklist/allowlist of orgs
- Add language/domain filters for role-specific runs
- Publish to Notion/Slack endpoints
