# Purpose
Automate a daily job that discovers **global, cutting‑edge** builders (active on new/just‑released tech in the last 30 days), computes a **100‑pt score**, and publishes a leaderboard (CSV + Markdown) to a repo, Gist, or Notion.

---

## High‑level Architecture
- **Agent runtime**: Claude Agent SDK (TypeScript)
- **Tools**: shell (`gh`, `jq`, `python3`), file I/O
- **Data sources**: GitHub GraphQL + REST (releases), optional GH Archive (BigQuery) for pre‑filtering at scale
- **Scheduler**: GitHub Actions (cron) or any external cron
- **Artifacts**: `leaderboard.jsonl`, `leaderboard.csv`, `leaderboard.md`

---

## Scoring Model (100 pts)
- **Activity & quality (60)**: recent merged PRs; code reviews; (future) CI pass; issue responsiveness
- **Reputation (25)**: followers (log‑scaled); stars on owned repos; maintainer roles (future)
- **Fit & availability (15)**: stack/domain match as needed; `isHireable`/bio signals/Sponsors

---

## Agent Tools
```ts
import { Agent } from "@anthropic-ai/claude-agent-sdk";
import { execFileSync } from "node:child_process";
import fs from "node:fs";

function sh(cmd: string, args: string[] = []) {
  return execFileSync(cmd, args, { encoding: "utf8" });
}
function ghJson(args: string[]) {
  const out = sh("gh", args);
  return JSON.parse(out);
}

export const agent = new Agent({ name: "CuttingEdge GH Leaderboard" });
```

### Tool: `seedRepos`
Find repos created or pushed in the last 30 days; emphasize those with a **recent release**.
```ts
agent.tool("seedRepos", async ({ days = 30, minStars = 50, limit = 200 }) => {
  const sinceDate = new Date(Date.now() - days*24*3600*1000).toISOString().slice(0,10);
  const qA = `created:>=${sinceDate} stars:>=${minStars}`;
  const qB = `pushed:>=${sinceDate} stars:>=${minStars}`;
  const a = ghJson(["search","repos", qA, "--sort","stars","--order","desc","--limit", String(limit), "--json","nameWithOwner,stargazerCount,primaryLanguage,updatedAt"]);
  const b = ghJson(["search","repos", qB, "--sort","stars","--order","desc","--limit", String(limit), "--json","nameWithOwner,stargazerCount,primaryLanguage,updatedAt"]);
  const names = new Set([...a, ...b].map((r:any)=>r.nameWithOwner));
  // optional recent release filter
  const withRelease:string[] = [];
  for (const r of names) {
    try {
      const rel = sh("gh", ["api", `repos/${r}/releases/latest"]);
      const pub = JSON.parse(rel).published_at;
      if (new Date(pub).getTime() >= new Date(sinceDate).getTime()) withRelease.push(r as string);
    } catch {}
  }
  return { repos: withRelease.length ? withRelease : Array.from(names) };
});
```

### Tool: `recentContributors`
Collect merged‑PR authors since `sinceISO`.
```ts
agent.tool("recentContributors", async ({ repo, sinceISO }) => {
  const [owner, name] = (repo as string).split("/");
  const q = `query($owner:String!,$name:String!,$since:DateTime!){ repository(owner:$owner,name:$name){ pullRequests(states:MERGED,orderBy:{field:UPDATED_AT,direction:DESC},first:100){ nodes{ mergedAt author{login} commits(last:1){nodes{commit{committedDate}}} } } } }`;
  const out = sh("gh", ["api","graphql","-f","query="+q,"-F",`owner=${owner}`,"-F",`name=${name}`,"-F",`since=${sinceISO}`]);
  const nodes = JSON.parse(out).data.repository.pullRequests.nodes;
  return nodes.filter((n:any)=> new Date(n.mergedAt).getTime() >= new Date(sinceISO).getTime())
              .map((n:any)=>({ login:n.author?.login, mergedAt:n.mergedAt }));
});
```

### Tool: `hydrateUser`
Fetch user details, repo/star profile, PRs, reviews, and soft availability.
```ts
agent.tool("hydrateUser", async ({ login, sinceISO }) => {
  const q = `query($login:String!,$from:DateTime!){ user(login:$login){ login name bio company location followers{totalCount} isHireable repositories(isFork:false, privacy:PUBLIC, first:50, orderBy:{field:STARGAZERS,direction:DESC}){ nodes{name stargazerCount} } pullRequests(states:MERGED, first:50, orderBy:{field:UPDATED_AT,direction:DESC}){ nodes{ mergedAt repository{stargazerCount nameWithOwner} reviews{totalCount} } } contributionsCollection(from:$from){ totalCommitContributions pullRequestReviewContributions(first:100){ totalCount } } sponsorshipsAsMaintainer(first:1){ totalCount } } }`;
  const out = sh("gh", ["api","graphql","-f","query="+q,"-F",`login=${login}`,"-F",`from=${sinceISO}`]);
  return JSON.parse(out).data.user;
});
```

### Tool: `scoreUsers`
Apply the 100‑pt rubric; return sorted array.
```ts
agent.tool("scoreUsers", async ({ users, sinceISO }) => {
  function log10(x:number){ return Math.log10(Math.max(1,x)); }
  const rows = users.map((u:any)=>{
    const prs = u.pullRequests?.nodes || [];
    const mergedRecent = prs.filter((p:any)=> new Date(p.mergedAt).getTime() >= new Date(sinceISO).getTime());
    const reviews = prs.reduce((a:number,p:any)=> a + (p.reviews?.totalCount||0), 0);
    // 60
    const s_activity = Math.min(25, mergedRecent.length);
    const s_reviews = Math.min(15, Math.floor(reviews/3));
    const s_aq = s_activity + s_reviews;
    // 25
    const followers = u.followers?.totalCount || 0;
    const s_follow = Math.min(10, Math.floor(log10(followers)*10));
    const repoStars = (u.repositories?.nodes||[]).reduce((a:number,r:any)=> a + Math.min(200, r.stargazerCount||0), 0);
    const s_repo = Math.min(10, Math.floor(repoStars/500));
    const s_rep = s_follow + s_repo;
    // 15
    const hire = u.isHireable ? 5 : 0;
    const bio = (u.bio||'').toLowerCase();
    const avail = (bio.includes('freelance')||bio.includes('consult')||bio.includes('contract')) ? 3 : 0;
    const s_fit = 10 + Math.max(hire, avail);
    const score = s_aq + s_rep + s_fit;
    return { login:u.login, name:u.name, followers, merged_recent: mergedRecent.length, reviews, score };
  });
  rows.sort((a:any,b:any)=> b.score - a.score);
  return rows;
});
```

---

## Orchestration Task: `buildLeaderboard`
```ts
agent.task("buildLeaderboard", async ({ days = 30, minStars = 50, limit = 200, top = 200 }) => {
  const sinceISO = new Date(Date.now() - days*24*3600*1000).toISOString();
  const { repos } = await agent.runTool("seedRepos", { days, minStars, limit });
  const seen = new Set<string>();
  for (const r of repos) {
    const authors = await agent.runTool("recentContributors", { repo: r, sinceISO });
    authors.forEach((a:any)=> a?.login && seen.add(a.login));
  }
  const users:any[] = [];
  for (const login of Array.from(seen)) {
    try { users.push(await agent.runTool("hydrateUser", { login, sinceISO })); } catch {}
  }
  const scored = await agent.runTool("scoreUsers", { users, sinceISO });
  const topRows = scored.slice(0, top);
  // write artifacts
  fs.writeFileSync("leaderboard.jsonl", topRows.map(r=>JSON.stringify(r)).join("\n"));
  fs.writeFileSync("leaderboard.csv", [
    "rank,login,name,score,followers,merged_recent,reviews",
    ...topRows.map((r,i)=>`${i+1},${r.login},${r.name||""},${r.score},${r.followers},${r.merged_recent},${r.reviews}`)
  ].join("\n"));
  const md = [
    "| Rank | Login | Score | Followers | Merged PRs | Reviews |",
    "|---|---:|---:|---:|---:|---:|",
    ...topRows.map((r,i)=>`| ${i+1} | [${r.login}](https://github.com/${r.login}) | ${r.score} | ${r.followers} | ${r.merged_recent} | ${r.reviews} |`)
  ].join("\n");
  fs.writeFileSync("leaderboard.md", md);
  return { count: topRows.length };
});
```

---

## Scheduler (GitHub Actions)
```yaml
name: cutting-edge-leaderboard
on:
  schedule:
    - cron: "17 3 * * *"   # daily 03:17 UTC
  workflow_dispatch: {}
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - name: Install CLI deps
        run: |
          sudo apt-get update && sudo apt-get install -y jq python3
          type -p gh >/dev/null || (type -p brew && brew install gh) || sudo apt-get install -y gh
      - name: Auth GH
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: gh auth setup-git && gh auth status
      - name: Install agent
        run: npm i -D @anthropic-ai/claude-agent-sdk
      - name: Run agent
        run: node agent.js
      - name: Commit artifacts
        run: |
          git config user.email "bot@example.com"
          git config user.name "Leaderboard Bot"
          git add leaderboard.*
          git commit -m "update leaderboard $(date -u +'%Y-%m-%d')" || echo "no changes"
          git push
```

---

## Configuration
- **Params**: `days`, `minStars`, `limit`, `top` are surfaced on `buildLeaderboard` task
- **Secrets**: use `GITHUB_TOKEN` (or a PAT) for CLI calls
- **Outputs**: Artifacts written to repo root; adjust paths as needed

---

## Extensions & Hardening
- Add Checks API to compute **CI pass rate** for candidate PRs
- Pull **issues** to compute responsiveness SLA
- Pre‑filter using **GH Archive** (BigQuery) to scale to 10k+ candidates
- Maintain a blocklist and a positive allowlist of orgs
- Add **language/domain filters** for role‑specific runs (e.g., Rust systems, JS full‑stack, LLM tooling)
- Publish to Notion/Slack; attach CSV

---

## Quick Start
1) Save this file as `agent.js` (or TS variant)
2) `npm i @anthropic-ai/claude-agent-sdk`
3) Ensure `gh` is installed & authed
4) `node agent.js` to produce `leaderboard.*`
5) Wire the GitHub Action for daily updates

