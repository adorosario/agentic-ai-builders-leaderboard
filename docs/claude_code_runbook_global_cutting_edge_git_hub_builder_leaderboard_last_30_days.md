# Goal
Produce a ranked leaderboard of outstanding builders on GitHub who have been active on *tech released/created in the last 30 days*, across any language. The workflow runs entirely from the command line using **Claude Code (CLI)** to orchestrate `gh` (GitHub CLI) calls and a small local scoring function.

---

## Overview
1) **Seed repos** created/updated in the last 30 days (global; any language; star‑weighted) 
2) **Extract recent contributors** (merged PR authors & active committers) 
3) **Hydrate candidate profiles** with richer signals (followers, repo stars, reviews) 
4) **Score** using a 100‑point rubric 
5) **Export** CSV/Markdown leaderboard

> “Cutting‑edge” definition here = contributors to repos **created** or **actively released/updated** within the last 30 days.

---

## Prereqs
- Install and auth: `gh auth login` (token with `read:org`, `repo`, `read:user` is sufficient for public data)
- Claude Code CLI (Node 18+)
- `jq`, `awk`, `sed`, `python3` available

```bash
# sanity checks
gh --version
claude --version
jq --version
```

---

## Tunables
```bash
# Window
DAYS=30
SINCE=$(date -u -v-${DAYS}d +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -d "-${DAYS} days" +%Y-%m-%dT00:00:00Z)

# Repo gates (adjust to taste)
MIN_STARS=50          # avoid toy repos
MAX_REPOS=200         # initial seed size
TOP_N=200             # final candidate pool size before scoring/export
```

> macOS uses `-v`; Linux uses `-d`. The line above tries macOS first, then Linux.

---

## 1) Seed “new or newly hot” repos (last 30 days)
We combine two signals:
- **Created recently** (brand new) and star‑sorted
- **Pushed recently** with a **release** in the last 30 days

```bash
# A. New repos created in the window
REPOS_CREATED=$(gh search repos "created:>=$(echo $SINCE | cut -dT -f1) stars:>=$MIN_STARS" \
  --sort stars --order desc --limit $MAX_REPOS \
  --json nameWithOwner,stargazerCount,primaryLanguage,updatedAt | jq -c '.[]')

# B. Actively updated repos; we’ll later filter by recent releases
REPOS_PUSHED=$(gh search repos "pushed:>=$(echo $SINCE | cut -dT -f1) stars:>=$MIN_STARS" \
  --sort stars --order desc --limit $MAX_REPOS \
  --json nameWithOwner,stargazerCount,primaryLanguage,updatedAt | jq -c '.[]')

# Merge & unique
SEED=$(printf "%s\n%s\n" "$REPOS_CREATED" "$REPOS_PUSHED" | jq -s 'unique_by(.nameWithOwner)')

echo "$SEED" | jq '. | length'  # how many repos
```

### 1b) Keep repos with a **recent release** (optional but strong signal)
```bash
RECENT_RELEASE_REPOS=$(echo "$SEED" | jq -r '.[].nameWithOwner' | \
  xargs -I{} gh api \
    -H "Accept: application/vnd.github+json" \
    repos/{}/releases/latest 2>/dev/null | \
  jq -r 'select(.published_at >= env.SINCE) | .html_url' | sed 's#https://github.com/##; s#/releases/.*##')
```

### 1c) Final seed set
```bash
# Union of created/pushed and recent-release repos
FINAL_SEED=$(printf "%s\n" "$RECENT_RELEASE_REPOS" | sort -u)

# Fallback if releases were sparse: take top of original SEED
if [ -z "$FINAL_SEED" ]; then
  FINAL_SEED=$(echo "$SEED" | jq -r '.[].nameWithOwner' | head -n $MAX_REPOS)
fi

printf "%s\n" $FINAL_SEED | head
```

---

## 2) Extract recent contributors (merged PRs & commits in window)
```bash
CANDIDATES_FILE=candidates_raw.jsonl
> $CANDIDATES_FILE

for REPO in $FINAL_SEED; do
  # Pull merged PRs since SINCE
  gh api graphql -f query='\
  query($owner:String!, $name:String!, $since:DateTime!) {\
    repository(owner:$owner, name:$name) {\
      pullRequests(states:MERGED, orderBy:{field:UPDATED_AT, direction:DESC}, first:100) {\
        nodes {\
          mergedAt\
          author { login }\
          commits(last:1) { nodes { commit { committedDate } } }\
        }\
      }\
    }\
  }' -F owner="$(echo $REPO | cut -d/ -f1)" -F name="$(echo $REPO | cut -d/ -f2)" -F since="$SINCE" | \
  jq -c --arg SINCE "$SINCE" '\
    .data.repository.pullRequests.nodes\
    | map(select(.mergedAt >= $SINCE))\
    | map({login:.author.login, mergedAt, committedDate:(.commits.nodes[0].commit.committedDate)})\
    | .[]' >> $CANDIDATES_FILE

done

# Unique logins
LOGINS=$(jq -r '.login' $CANDIDATES_FILE | sort -u)
printf "%s\n" $LOGINS | head
```

> Tip: You can also add a commit‑based pass using `gh api repos/{owner}/{repo}/commits?since=...` to catch direct pushers in small repos.

---

## 3) Hydrate candidate profiles with richer signals
```bash
HYDRATED=hydrated.jsonl
> $HYDRATED

for U in $LOGINS; do
  gh api graphql -f query='\
  query($login:String!) {\
    user(login:$login) {\
      login\
      name\
      bio\
      company\
      location\
      followers { totalCount }\
      isHireable\
      isEmployee\
      repositories(isFork:false, privacy:PUBLIC, first:50, orderBy:{field:STARGAZERS, direction:DESC}) {\
        totalCount\
        nodes { name stargazerCount primaryLanguage { name } }\
      }\
      pullRequests(states:MERGED, first:50, orderBy:{field:UPDATED_AT, direction:DESC}) {\
        nodes {\
          mergedAt\
          repository { stargazerCount nameWithOwner }\
          reviews { totalCount }\
        }\
      }\
      contributionsCollection(from: $from) {\
        totalCommitContributions\
        pullRequestReviewContributions(first: 100) { totalCount }\
      }\
      # Sponsors (soft signal)
      sponsorshipsAsMaintainer(first: 1) { totalCount }\
    }\
  }' -F login="$U" -F from="$SINCE" | jq -c '.data.user' >> $HYDRATED

done
```

---

## 4) Scoring (100‑point rubric)
```python
# save as score.py
import json, math, sys

scores = []
for line in sys.stdin:
    u = json.loads(line)
    if not u: 
        continue
    followers = u.get('followers',{}).get('totalCount',0)
    repos = u.get('repositories',{}).get('nodes',[])
    prs = u.get('pullRequests',{}).get('nodes',[])
    reviews = sum(p.get('reviews',{}).get('totalCount',0) for p in prs)
    merged_recent = [p for p in prs if p.get('mergedAt','') >= sys.argv[1]]
    pr_weighted = sum(min(200, p.get('repository',{}).get('stargazerCount',0)) for p in merged_recent)

    # Activity & quality (60)
    s_activity = min(25, len(merged_recent))
    s_reviews  = min(15, int(reviews/3))
    s_ci = 0  # placeholder if you add Checks API
    s_issue_resp = 0  # placeholder; add later from issues API
    s_aq = s_activity + s_reviews + s_ci + s_issue_resp

    # Reputation (25)
    s_follow = min(10, int(math.log10(max(1, followers))*10))
    s_repo_stars = min(10, sum(min(200, r.get('stargazerCount',0)) for r in repos)//500)
    s_maintain = 0  # set via org/maintainer heuristics later
    s_rep = s_follow + s_repo_stars + s_maintain

    # Fit & availability (15)
    hireable = 5 if u.get('isHireable') else 0
    bio = (u.get('bio') or '').lower()
    avail_kw = any(k in bio for k in ['freelance','available','consult','contract'])
    s_avail = max(hireable, 3 if avail_kw else 0)
    s_langfit = 10  # global search; give neutral 10; override if filtering by stack

    score = s_aq + s_rep + s_avail + s_langfit

    scores.append({
        'login': u.get('login'),
        'name': u.get('name'),
        'followers': followers,
        'merged_recent': len(merged_recent),
        'reviews': reviews,
        'score': int(score)
    })

scores.sort(key=lambda x: x['score'], reverse=True)
for s in scores[:200]:
    print(json.dumps(s))
```

Run scoring:
```bash
python3 score.py "$SINCE" < $HYDRATED > leaderboard.jsonl
```

---

## 5) Export CSV & Markdown
```bash
jq -r '["rank","login","name","score","followers","merged_recent","reviews"],
      (to_entries | sort_by(.value.score) | reverse | .[] | [.key+1, .value.login, .value.name, .value.score, .value.followers, .value.merged_recent, .value.reviews])
      | @csv' leaderboard.jsonl > leaderboard.csv

# Markdown top 50
jq -r 'sort_by(.score) | reverse | .[:50] | 
      ("| Rank | Login | Score | Followers | Merged PRs | Reviews |\n|---|---:|---:|---:|---:|---:|"),
      to_entries[] | "| \(.key+1) | [\(.value.login)](https://github.com/\(.value.login)) | \(.value.score) | \(.value.followers) | \(.value.merged_recent) | \(.value.reviews) |"' \
      leaderboard.jsonl > leaderboard.md
```

---

## Optional Improvements
- Add **Checks API** to compute CI pass rate on candidate PRs
- Add **issue responsiveness** from Issues API (opened vs closed; median time‑to‑first‑response)
- Pre‑filter at scale using **GH Archive** in BigQuery, then hydrate shortlist via GraphQL
- Enrich with registry stats (npm/pip crates) for “ecosystem impact”

---

## One‑shot with Claude Code
Paste the following into Claude Code’s terminal to run end‑to‑end:
```bash
# 0) params
DAYS=30; MIN_STARS=50; MAX_REPOS=200; TOP_N=200
SINCE=$(date -u -v-${DAYS}d +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -d "-${DAYS} days" +%Y-%m-%dT00:00:00Z)

# 1) seed
REPOS_CREATED=$(gh search repos "created:>=$(echo $SINCE | cut -dT -f1) stars:>=$MIN_STARS" --sort stars --order desc --limit $MAX_REPOS --json nameWithOwner,stargazerCount,primaryLanguage,updatedAt | jq -c '.[]')
REPOS_PUSHED=$(gh search repos "pushed:>=$(echo $SINCE | cut -dT -f1) stars:>=$MIN_STARS" --sort stars --order desc --limit $MAX_REPOS --json nameWithOwner,stargazerCount,primaryLanguage,updatedAt | jq -c '.[]')
SEED=$(printf "%s\n%s\n" "$REPOS_CREATED" "$REPOS_PUSHED" | jq -s 'unique_by(.nameWithOwner)')
RECENT_RELEASE_REPOS=$(echo "$SEED" | jq -r '.[].nameWithOwner' | xargs -I{} sh -c 'gh api repos/{}/releases/latest 2>/dev/null || true' | jq -r 'select(.published_at >= env.SINCE) | .html_url' | sed 's#https://github.com/##; s#/releases/.*##')
FINAL_SEED=$(printf "%s\n" "$RECENT_RELEASE_REPOS" | sort -u)
if [ -z "$FINAL_SEED" ]; then FINAL_SEED=$(echo "$SEED" | jq -r '.[].nameWithOwner' | head -n $MAX_REPOS); fi

# 2) contributors
CANDIDATES_FILE=candidates_raw.jsonl; > $CANDIDATES_FILE
for REPO in $FINAL_SEED; do
  gh api graphql -f query='query($owner:String!, $name:String!, $since:DateTime!){ repository(owner:$owner, name:$name){ pullRequests(states:MERGED, orderBy:{field:UPDATED_AT, direction:DESC}, first:100){ nodes{ mergedAt author{login} commits(last:1){nodes{commit{committedDate}}}}}}}' -F owner="$(echo $REPO | cut -d/ -f1)" -F name="$(echo $REPO | cut -d/ -f2)" -F since="$SINCE" | jq -c --arg SINCE "$SINCE" '.data.repository.pullRequests.nodes | map(select(.mergedAt >= $SINCE)) | map({login:.author.login, mergedAt, committedDate:(.commits.nodes[0].commit.committedDate)}) | .[]' >> $CANDIDATES_FILE
done
LOGINS=$(jq -r '.login' $CANDIDATES_FILE | sort -u)

# 3) hydrate
HYDRATED=hydrated.jsonl; > $HYDRATED
for U in $LOGINS; do
  gh api graphql -f query='query($login:String!, $from:DateTime!){ user(login:$login){ login name bio company location followers{totalCount} isHireable isEmployee repositories(isFork:false, privacy:PUBLIC, first:50, orderBy:{field:STARGAZERS, direction:DESC}){ totalCount nodes{name stargazerCount primaryLanguage{name}} } pullRequests(states:MERGED, first:50, orderBy:{field:UPDATED_AT, direction:DESC}){ nodes{ mergedAt repository{stargazerCount nameWithOwner} reviews{totalCount} } } contributionsCollection(from:$from){ totalCommitContributions pullRequestReviewContributions(first:100){ totalCount } } sponsorshipsAsMaintainer(first:1){ totalCount } } }' -F login="$U" -F from="$SINCE" | jq -c '.data.user' >> $HYDRATED
done

# 4) score
python3 - <<'PY'
import json, math, sys
SINCE = ""$SINCE""
users = [json.loads(l) for l in open("hydrated.jsonl") if l.strip()]
rows = []
for u in users:
  followers = u.get('followers',{}).get('totalCount',0)
  prs = u.get('pullRequests',{}).get('nodes',[])
  reviews = sum(p.get('reviews',{}).get('totalCount',0) for p in prs)
  merged_recent = [p for p in prs if p.get('mergedAt','') >= SINCE]
  # activity & quality
  s_activity = min(25, len(merged_recent))
  s_reviews  = min(15, int(reviews/3))
  s_aq = s_activity + s_reviews
  # reputation
  repos = u.get('repositories',{}).get('nodes',[])
  s_follow = min(10, int(math.log10(max(1, followers))*10))
  s_repo_stars = min(10, sum(min(200, r.get('stargazerCount',0)) for r in repos)//500)
  s_rep = s_follow + s_repo_stars
  # availability
  hireable = 5 if u.get('isHireable') else 0
  bio = (u.get('bio') or '').lower()
  avail_kw = any(k in bio for k in ['freelance','available','consult','contract'])
  s_avail = max(hireable, 3 if avail_kw else 0) + 10  # language fit neutral 10
  score = s_aq + s_rep + s_avail
  rows.append({"login":u.get('login'),"name":u.get('name'),"followers":followers,"merged_recent":len(merged_recent),"reviews":reviews,"score":int(score)})
rows.sort(key=lambda r:r['score'], reverse=True)
open('leaderboard.jsonl','w').write("\n".join(json.dumps(r) for r in rows[:200]))
PY

# 5) export
jq -r ' ["rank","login","name","score","followers","merged_recent","reviews"], (to_entries | .[] | [.key+1, .value.login, .value.name, .value.score, .value.followers, .value.merged_recent, .value.reviews]) | @csv' <(jq -s 'fromstream( inputs | . ) | to_entries' leaderboard.jsonl) > leaderboard.csv

jq -r ' sort_by(.score) | reverse | .[:50] | ("| Rank | Login | Score | Followers | Merged PRs | Reviews |\n|---|---:|---:|---:|---:|---:|"), to_entries[] | "| \(.key+1) | [\(.value.login)](https://github.com/\(.value.login)) | \(.value.score) | \(.value.followers) | \(.value.merged_recent) | \(.value.reviews) |" ' leaderboard.jsonl > leaderboard.md

sed -n '1,10p' leaderboard.md
```