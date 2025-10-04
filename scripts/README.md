# Scripts Documentation

This directory contains all the automation scripts for generating the Agentic AI Builders Leaderboard.

## Main Script

### `run_leaderboard.sh`

**Purpose:** Orchestrates the entire leaderboard generation workflow.

**Usage:**
```bash
./scripts/run_leaderboard.sh
```

**Steps:**
1. Discovers ~200 agentic AI repositories updated in last 30 days
2. Extracts contributors with merged PRs
3. Hydrates contributor profiles via GitHub API
4. Scores using 100-point rubric
5. Exports CSV and Markdown leaderboards

**Runtime:** ~15-20 minutes (depends on API rate limits)

**Requirements:**
- `gh` (GitHub CLI) authenticated
- `jq` for JSON processing
- `python3` with standard library

---

## Component Scripts

### `extract_contributors_rest.sh`

**Purpose:** Extract contributors from agentic AI repositories using GitHub REST API.

**Input:** `agentic_seed.jsonl` (list of repositories)

**Output:** `candidates_raw.jsonl` (contributors with merged PRs)

**How it works:**
```bash
# For each repo:
GET /repos/{owner}/{repo}/pulls?state=closed&per_page=100

# Filters for:
- merged_at >= SINCE_DATE (last 30 days)
- author is not null
```

**Typical output:** ~300 contributors from ~30 repos

---

### `hydrate_profiles.sh`

**Purpose:** Fetch comprehensive GitHub profiles using GraphQL API.

**Input:** `candidates_raw.jsonl` (unique contributor logins)

**Output:** `hydrated.jsonl` (full profile data)

**Data fetched per user:**
- Basic info (name, bio, company, location)
- Followers count
- Top 50 repositories by stars
- Recent 50 merged PRs
- Code review activity
- Hiring availability (`isHireable`)

**Rate limiting:** Pauses every 20 requests to respect GitHub API limits

**Typical output:** ~270 hydrated profiles (~1.7MB)

---

### `score.py`

**Purpose:** Apply 100-point scoring rubric to candidates.

**Input:** `hydrated.jsonl`

**Output:**
- `leaderboard.jsonl` (top 200 scored candidates)
- Console output with top 10

**Scoring breakdown:**
```python
# Activity & Quality (60 pts)
s_activity = min(25, len(merged_recent_prs))
s_reviews = min(15, int(total_reviews / 3))

# Reputation (25 pts)
s_followers = min(10, int(log10(followers) * 10))
s_repo_stars = min(10, total_repo_stars // 500)

# Availability (15 pts)
s_hireable = 5 if isHireable else 0
s_bio_keywords = 3 if has_availability_keywords else 0
s_stack_fit = 10  # neutral for global search

total_score = activity + reputation + availability
```

**Typical output:** 200 candidates scored

---

### `export.py`

**Purpose:** Export leaderboard in multiple formats.

**Input:** `leaderboard.jsonl`

**Outputs:**
- `leaderboard.csv` - Spreadsheet-friendly format (all 200 entries)
- `leaderboard.md` - GitHub-formatted table (top 50)

**CSV columns:**
```
rank, login, name, score, followers, merged_recent, reviews,
isHireable, company, location
```

**Markdown format:**
```markdown
| Rank | Login | Name | Score | Followers | Merged PRs | Reviews | Hireable | Company |
```

---

## Customization

### Adjust Time Window

Edit `run_leaderboard.sh`:
```bash
DAYS=30  # Change to 7, 14, 60, 90, etc.
```

### Filter by Language

Add to `run_leaderboard.sh`:
```bash
gh search repos "agent AI language:python pushed:>=$SINCE"
```

### Change Minimum Stars Threshold

Edit `run_leaderboard.sh`:
```bash
MIN_STARS=50  # Higher = more selective, Lower = more inclusive
```

### Customize Scoring Weights

Edit `score.py`:
```python
# Example: Give more weight to reviews
s_reviews = min(20, int(reviews / 2))  # Up to 20 pts instead of 15
```

---

## Troubleshooting

### "gh: command not found"
Install GitHub CLI:
```bash
brew install gh          # macOS
sudo apt install gh      # Linux
winget install GitHub.cli  # Windows
```

### "jq: command not found"
Install jq:
```bash
brew install jq          # macOS
sudo apt install jq      # Linux
```

### GitHub API Rate Limit Exceeded
```bash
# Check your rate limit status
gh api rate_limit

# Wait or use multiple GitHub tokens
export GITHUB_TOKEN="your_token_here"
```

### Empty leaderboard.jsonl
- Ensure `gh auth login` is successful
- Check that `agentic_seed.jsonl` contains repos
- Verify SINCE date is not too recent (should be 30 days ago)

---

## Performance Notes

**Bottlenecks:**
1. GitHub API rate limits (5,000 requests/hour)
2. Network latency for 200+ API calls
3. Profile hydration is slowest step (~10 mins)

**Optimizations:**
- Batch GraphQL queries (done)
- Cache hydrated profiles locally (manual)
- Use GitHub Archive (BigQuery) for initial filtering (future)

---

## Future Enhancements

- [ ] Parallel API calls with async/await
- [ ] Cache profiles to avoid re-fetching
- [ ] Add CI pass rate using Checks API
- [ ] Track issue responsiveness
- [ ] Generate trend charts over time
- [ ] Support multiple programming languages separately

---

**Last Updated:** 2025-10-03
