#!/usr/bin/env python3
import json
import csv

# Read leaderboard
with open('leaderboard.jsonl', 'r') as f:
    data = [json.loads(line) for line in f]

# Export CSV
with open('leaderboard.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['rank', 'login', 'name', 'score', 'followers', 'merged_recent', 'reviews', 'isHireable', 'company', 'location'])
    for i, row in enumerate(data):
        writer.writerow([
            i + 1,
            row['login'],
            row.get('name', ''),
            row['score'],
            row['followers'],
            row['merged_recent'],
            row['reviews'],
            row.get('isHireable', False),
            row.get('company', ''),
            row.get('location', '')
        ])

print(f"✅ Created leaderboard.csv with {len(data)} entries")

# Export Markdown
with open('leaderboard.md', 'w') as f:
    f.write("# Top 50 Agentic AI Builders (Last 30 Days)\n\n")
    f.write("| Rank | Login | Name | Score | Followers | Merged PRs | Reviews | Hireable | Company |\n")
    f.write("|---:|:---|:---|---:|---:|---:|---:|:---:|:---|\n")

    for i, row in enumerate(data[:50]):
        hireable = "✅" if row.get('isHireable') else ""
        company = row.get('company') or "N/A"
        name = row.get('name') or "N/A"
        f.write(f"| {i+1} | [{row['login']}](https://github.com/{row['login']}) | {name} | {row['score']} | {row['followers']} | {row['merged_recent']} | {row['reviews']} | {hireable} | {company} |\n")

print(f"✅ Created leaderboard.md with top 50 entries")
