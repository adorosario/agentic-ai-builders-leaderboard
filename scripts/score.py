#!/usr/bin/env python3
import json
import math

SINCE = "2025-09-03T00:00:00Z"

# Read hydrated profiles
with open("hydrated.jsonl", "r") as f:
    users = [json.loads(line) for line in f if line.strip()]

rows = []
for u in users:
    if not u:  # Skip null entries
        continue

    login = u.get('login', 'unknown')
    followers = u.get('followers', {}).get('totalCount', 0)
    prs = u.get('pullRequests', {}).get('nodes', [])
    reviews = sum(p.get('reviews', {}).get('totalCount', 0) for p in prs)
    merged_recent = [p for p in prs if p.get('mergedAt', '') >= SINCE]

    # Activity & quality (60 points)
    s_activity = min(25, len(merged_recent))
    s_reviews = min(15, int(reviews / 3))
    s_aq = s_activity + s_reviews

    # Reputation (25 points)
    repos = u.get('repositories', {}).get('nodes', [])
    s_follow = min(10, int(math.log10(max(1, followers)) * 10))
    s_repo_stars = min(10, sum(min(200, r.get('stargazerCount', 0)) for r in repos) // 500)
    s_rep = s_follow + s_repo_stars

    # Availability (15 points)
    hireable = 5 if u.get('isHireable') else 0
    bio = (u.get('bio') or '').lower()
    avail_kw = any(k in bio for k in ['freelance', 'available', 'consult', 'contract'])
    s_avail = max(hireable, 3 if avail_kw else 0) + 10  # +10 language fit neutral

    score = s_aq + s_rep + s_avail

    rows.append({
        "login": login,
        "name": u.get('name'),
        "company": u.get('company'),
        "location": u.get('location'),
        "bio": u.get('bio'),
        "followers": followers,
        "merged_recent": len(merged_recent),
        "reviews": reviews,
        "isHireable": u.get('isHireable'),
        "score": int(score)
    })

# Sort by score
rows.sort(key=lambda r: r['score'], reverse=True)

# Write top 200
with open('leaderboard.jsonl', 'w') as f:
    for row in rows[:200]:
        f.write(json.dumps(row) + '\n')

print(f"Scored {len(rows)} candidates")
print(f"Top 10:")
for i, row in enumerate(rows[:10]):
    print(f"{i+1}. {row['login']} - {row['score']} points")
