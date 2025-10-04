# 📐 Methodology

## Overview

This leaderboard ranks GitHub developers based on their **recent contributions to agentic AI technology**. The system is designed to identify active, high-quality builders rather than simply rewarding historical popularity.

## Data Collection Process

### 1. Repository Discovery (Seed Phase)

We identify "cutting-edge" repositories using GitHub search with these criteria:

```bash
# Search parameters
DAYS=30                    # Time window for recent activity
MIN_STARS=20              # Minimum threshold for serious projects
MAX_REPOS_PER_QUERY=100   # Results per search query
```

**Search Queries:**
- `"agent AI" pushed:>=2025-09-03 stars:>=20`
- `"langchain" pushed:>=2025-09-03 stars:>=20`
- `"langgraph" pushed:>=2025-09-03 stars:>=5`
- `"LLM agent" pushed:>=2025-09-03 stars:>=20`

**Specific High-Signal Repos:**
- `anthropics/anthropic-sdk-typescript` - Claude Agent SDK
- `langchain-ai/langgraph` - Agent orchestration
- `openai/openai-python` - OpenAI SDK
- `langfuse/langfuse` - LLM observability
- `crewAIInc/crewAI` - Multi-agent framework
- + 200 more repositories

**Result:** ~201 unique agentic AI repositories

---

### 2. Contributor Extraction

For each repository, we extract developers with **merged pull requests** in the last 30 days:

```bash
# Using GitHub REST API
GET /repos/{owner}/{repo}/pulls?state=closed&per_page=100&sort=updated

# Filter for:
- merged_at >= SINCE_DATE (2025-09-03)
- Pull requests (not just issues)
```

**Why merged PRs?**
- Stronger signal than commits (shows collaboration)
- Filters out bots and trivial contributions
- Indicates code quality (passed review)

**Result:** ~272 unique contributors across all repos

---

### 3. Profile Hydration

For each contributor, we fetch comprehensive profile data via GitHub GraphQL API:

```graphql
query($login: String!, $from: DateTime!) {
  user(login: $login) {
    login, name, bio, company, location
    followers { totalCount }
    isHireable
    isEmployee

    # Top repositories by stars
    repositories(isFork: false, privacy: PUBLIC, first: 50,
                 orderBy: {field: STARGAZERS, direction: DESC}) {
      totalCount
      nodes {
        name
        stargazerCount
        primaryLanguage { name }
      }
    }

    # Recent merged pull requests
    pullRequests(states: MERGED, first: 50,
                 orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        mergedAt
        repository { stargazerCount, nameWithOwner }
        reviews { totalCount }
      }
    }

    # Contribution stats
    contributionsCollection(from: $from) {
      totalCommitContributions
      pullRequestReviewContributions(first: 100) { totalCount }
    }

    # Sponsorship (soft signal)
    sponsorshipsAsMaintainer(first: 1) { totalCount }
  }
}
```

**Rate Limiting:**
- GraphQL: 5,000 points/hour (authenticated)
- REST: 5,000 requests/hour
- We add delays every 20 requests to stay within limits

---

## Scoring Rubric (100 Points)

### Activity & Quality (60 points total)

#### Recent Merged PRs (25 points)
```python
s_activity = min(25, len(merged_recent))
```
- **1 point per merged PR** in the last 30 days
- **Cap at 25** to prevent spam gaming
- Only counts PRs to repos in our seed list

**Rationale:** Direct measure of active contribution to agentic AI projects

---

#### Code Reviews (15 points)
```python
reviews = sum(pr.reviews.totalCount for pr in all_prs)
s_reviews = min(15, int(reviews / 3))
```
- **1 point per 3 reviews** given
- **Cap at 15 points**
- Counts reviews on any repository

**Rationale:** Shows mentorship, code quality focus, and collaboration

---

#### CI Pass Rate (10 points) *[Future]*
```python
s_ci = 0  # Placeholder
```
- Will use GitHub Checks API
- Measure % of PRs that pass CI on first attempt
- Indicates code quality and testing discipline

---

#### Issue Responsiveness (10 points) *[Future]*
```python
s_issue_resp = 0  # Placeholder
```
- Track median time-to-first-response on issues
- Reward maintainers who engage with community
- Use GitHub Issues API

---

### Reputation (25 points total)

#### Followers (10 points)
```python
s_follow = min(10, int(math.log10(max(1, followers)) * 10))
```
- **Log-scaled** to prevent outlier dominance
- Examples:
  - 10 followers = 10 points
  - 100 followers = 20 points (capped at 10)
  - 1,000 followers = 30 points (capped at 10)

**Rationale:** Followers indicate trust and influence, but shouldn't dominate the score

---

#### Repository Stars (10 points)
```python
total_stars = sum(min(200, repo.stargazerCount) for repo in repos)
s_repo_stars = min(10, total_stars // 500)
```
- Sum stars across user's top repositories
- **Cap individual repo at 200 stars** (prevents outlier repos)
- **1 point per 500 total stars**

**Rationale:** Measures impact of personal projects, but limits gaming

---

#### Maintainer Roles (5 points) *[Future]*
```python
s_maintain = 0  # Placeholder
```
- Detect org membership in agentic AI orgs
- Use GitHub Organizations API
- Bonus for being a core maintainer

---

### Fit & Availability (15 points total)

#### Hireable Status (5 points)
```python
hireable = 5 if user.isHireable else 0
```
- **5 points** if GitHub profile shows "Available for hire"
- **0 points** otherwise

**Rationale:** Signals openness to opportunities

---

#### Availability Keywords (3 points)
```python
bio = (user.bio or '').lower()
keywords = ['freelance', 'available', 'consult', 'contract']
avail_kw = any(k in bio for k in keywords)
s_avail_keywords = 3 if avail_kw else 0
```
- Scan bio for availability signals
- **3 points** if any keyword found

**Rationale:** Some developers signal availability in bio instead of checkbox

---

#### Stack Fit (10 points)
```python
s_langfit = 10  # Neutral for global agentic AI search
```
- Currently **neutral 10 points** for all candidates
- Future: Could filter by language (Python, TypeScript, etc.)

**Final Availability Score:**
```python
s_avail = max(hireable, s_avail_keywords) + s_langfit
```

---

## Final Score Calculation

```python
score = s_activity + s_reviews + s_ci + s_issue_resp +  # 60 pts
        s_follow + s_repo_stars + s_maintain +           # 25 pts
        s_avail                                          # 15 pts

# Total: 100 points
```

---

## Example: Top Scorer Breakdown

**Evan Tahler** (@arcade-ai) - **68 points**

| Category | Breakdown | Points |
|---|---|---:|
| **Activity** | 29 merged PRs in 30 days | 25 |
| **Reviews** | 78 reviews ÷ 3 | 15 |
| **Followers** | 350 followers → log10(350)*10 = 25 (capped) | 10 |
| **Repo Stars** | Top repos sum to ~1000 stars ÷ 500 | 2 |
| **Hireable** | ✅ Available | 5 |
| **Stack Fit** | Neutral | 10 |
| **TOTAL** | | **68** |

---

## Limitations & Biases

### Known Biases
1. **Recency bias**: Only counts last 30 days (by design)
2. **PR quantity over quality**: Small PRs score same as large refactors
3. **Popular repo bias**: Contributors to high-star repos get more visibility
4. **English bias**: Bio keyword matching works best in English

### What This Doesn't Measure
- **Code quality**: No AST analysis or complexity metrics
- **Impact**: A 1-line bug fix can be more valuable than 1000 lines
- **Private contributions**: Only public GitHub activity
- **Non-code contributions**: Design, docs, community work

### Anti-Gaming Measures
- **Cap PR count at 25**: Prevents spam PRs
- **Cap repo stars at 200 each**: Limits outlier project influence
- **Log-scale followers**: Prevents celebrity dominance
- **Require merged PRs**: Filters bots and trivial commits

---

## Future Enhancements

1. **CI Pass Rate**: Use Checks API to measure code quality
2. **Issue Triage**: Reward maintainers who close issues quickly
3. **Documentation**: Bonus for merged docs PRs
4. **Language Diversity**: Track polyglot developers
5. **Community Health**: Measure PR review turnaround time
6. **Domain Expertise**: Cluster by agent type (RAG, tools, multi-agent)

---

## Transparency

All code is open source. You can:
- ✅ Audit the scoring algorithm in `scripts/score.py`
- ✅ Replicate the entire workflow with `scripts/run_leaderboard.sh`
- ✅ Suggest improvements via GitHub Issues
- ✅ Fork and create domain-specific leaderboards

---

**Last Updated**: 2025-10-03
