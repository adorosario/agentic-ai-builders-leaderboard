ok tell me something : I want to identify people on GitHub that are available to work (as freelancers) -- but there needs to  be a scoring system that surfaces the best contributors. What would be the best way to do this? DOes the GitHub search option help with this? Is there a leaderboard? 

Great question. Short version: GitHub doesn’t have a native “freelancer leaderboard,” but you can (a) search for people who’ve explicitly marked themselves **Available for hire**, (b) filter by useful public signals (followers, repos, languages, location), and (c) layer your own scoring on top. Here’s a practical way to do it.

# How to find candidates

1. **Start with GitHub user search (built-in / API).**
   Use qualifiers to narrow by language, location, followers, repo counts, etc. Example (UI or REST search):
   `type:user language:python location:"Boston" followers:>50 repos:>10`
   GitHub documents these user qualifiers (language, location, repos, followers, sort) here. ([GitHub][1])

2. **Include people who opt-in as “Available for hire.”**
   GitHub has a hiring status users can set on their profile; it surfaces via the UI and the API (historically as a `hireable`/hiring status field). So you can add that as a positive signal. ([GitHub Docs][2])

3. **Hunt where work is advertised.**
   Search open issues labeled **help wanted** / **good first issue** to find contributors actively engaging in projects that welcome outside help:
   `is:issue is:open label:"help wanted"` (plus your languages/topics). These labels are first-class in GitHub search and widely used. ([GitHub Docs][3])

# Build a simple, defensible scoring model

You’ll get better results by ranking people with *multiple* signals instead of a single metric (like stars). A lightweight rubric that works well:

**Activity & quality (60 pts)**

* Recent merged PRs (last 6–12 mo) across relevant repos: up to **25 pts**
* Review signal (PRs reviewed; approvals received): up to **15 pts**
* Issue velocity (opened → closed rate; responsiveness): up to **10 pts**
* CI pass rate on their PRs: up to **10 pts**

**Reputation (25 pts)**

* Followers (log-scaled) & sustained stars on *their* repos: up to **10 pts**
* Maintainer/owner roles in notable repos: up to **10 pts**
* Package ecosystem impact (downloads/deps where applicable): up to **5 pts**

**Fit & availability (15 pts)**

* Languages & domains that match your brief: up to **10 pts**
* “Available for hire” / Sponsors open / public freelance note: up to **5 pts** ([GitHub Docs][2])

> Where to get the data
> • **GitHub REST/GraphQL APIs** for users, repos, PRs, issues, reviews, CI status. GraphQL is great when you need nested joins (user → PRs → reviews → CI). ([GitHub Docs][4])
> • **GH Archive / BigQuery** to compute activity at scale (events stream, hourly updated). Ideal if you want to rank thousands of developers quickly. ([GH Archive][5])

# Does GitHub Search help? Is there a leaderboard?

* **Search helps a lot for discovery and filtering**, including by language, location, followers, and more; you can sort users by followers/repos/joined. But **there’s no official freelancer leaderboard** or built-in quality score. You have to compute your own. ([GitHub][1])
* **3rd-party leaderboards exist**, but each has bias (e.g., stars, commits):

  * **commits.top** ranks by commit activity. ([Committers][6])
  * **GitRanks** aggregates stars/contributions/followers. ([gitranks.com][7])
  * **OSS Insight** offers rich analytics and rankings over GitHub events (great for building your own dashboards). ([ossinsight.io][8])
    Use these more as discovery aids than final truth.

# A concrete workflow you can run this week

1. **Seed & filter**

   * Query GitHub users with qualifiers for your stack/geo/seniority; include “help wanted” repos to mine recent contributors. ([GitHub][1])
2. **Score candidates**

   * Pull recent PRs/issues/reviews via GraphQL; compute the rubric above. ([GitHub Docs][9])
   * (Optional) Enrich with GH Archive to capture cross-repo activity efficiently. ([GH Archive][5])
3. **Shortlist & outreach**

   * Prioritize people with merged PRs in the last 90–180 days in projects that match your domain, *and* with “Available for hire.” ([GitHub Docs][2])
   * Reach out via GitHub profile links or repo Discussions/Issues.

# Example starter queries

* **People** (UI/API):
  `type:user language:typescript location:"Eastern Europe" followers:>100 repos:>20` ([GitHub][1])
* **Work signals** (issues):
  `org:vercel is:issue is:open label:"help wanted" language:typescript` ([GitHub Docs][3])

# Caveats

* GitHub ≠ résumé: private work, corporate repos, and non-code skills aren’t visible.
* Stars and raw commit counts are noisy; treat them as *one* input, not the decision. (Leaderboards like commits.top or GitRanks illustrate those biases.) ([Committers][6])

If you’d like, I can draft a tiny script outline (GraphQL queries + a scoring function) you can hand to your team to spin up a quick leaderboard.

[1]: https://github.com/github/docs/blob/main/content/search-github/searching-on-github/searching-users.md "docs/content/search-github/searching-on-github/searching-users.md at main · github/docs · GitHub"
[2]: https://docs.github.com/articles/what-does-the-available-for-hire-checkbox-do "Set your hiring status - GitHub Docs"
[3]: https://docs.github.com/articles/filtering-issues-and-pull-requests-by-labels?utm_source=chatgpt.com "Filtering and searching issues and pull requests - GitHub Docs"
[4]: https://docs.github.com/en/rest/users?utm_source=chatgpt.com "REST API endpoints for users - GitHub Docs"
[5]: https://www.gharchive.org/?utm_source=chatgpt.com "GH Archive"
[6]: https://committers.top/?utm_source=chatgpt.com "Most active GitHub users"
[7]: https://gitranks.com/?utm_source=chatgpt.com "GitRanks · GitHub Profile Analytics & Rankings"
[8]: https://ossinsight.io/?utm_source=chatgpt.com "OSS Insight"
[9]: https://docs.github.com/en/graphql?utm_source=chatgpt.com "GitHub GraphQL API documentation"

Could this possibly be done with the "gh" CLI and Claude Agent SDK? The ultimate goal here is to have a leaderboard of possible candidates to hire. 

Short answer: **Yes.** You can build a solid “available-to-hire” leaderboard using **`gh` (GitHub CLI)** to pull signals + **Claude Agent SDK** to orchestrate scoring, enrichment, and automated reports. There’s no native “freelancer leaderboard” on GitHub, but the combo lets you 1) discover candidates, 2) compute a multi-signal score, and 3) publish a ranked list automatically.

# What each piece does

* **`gh` CLI**

  * Discovery via search (users, issues with `help wanted`, repos). ([GitHub CLI][1])
  * Deep data via **GraphQL** in one call (PRs merged, review count, CI results, languages, “hireable”/hiring-status, followers, etc.). ([The GitHub Blog][2])
* **Claude Agent SDK**

  * Runs the workflow end-to-end: calls shell tools, paginates, retries, aggregates, computes the score, and outputs a daily/weekly leaderboard (CSV/Markdown/Notion/Gist). ([Claude Docs][3])

---

# Workflow blueprint (copy/paste friendly)

## 1) Seed candidates with `gh search`

Start broad (stack, geo, minimum reputation), then refine.

```bash
# Example: senior TypeScript devs in Eastern Europe with meaningful footprint
gh search users 'type:user language:TypeScript location:"Eastern Europe" followers:>50 repos:>15' \
  --sort followers --order desc --limit 200 --json login,name,location,followers
```

Docs: `gh search` + user qualifiers. ([GitHub CLI][1])

Also mine **work signals** where people already self-select into work:

```bash
# Open issues that welcome outside help in your ecosystem
gh search issues 'is:issue is:open label:"help wanted" language:TypeScript' \
  --limit 1000 --json repositoryUrl,title,number,author,assignees
```

(“help wanted” is a first-class label pattern across repos.) ([GitHub Docs][4])

## 2) Pull rich signals via GraphQL (with `gh api graphql`)

Use a single batched query per candidate to fetch the last 6–12 months of activity:

```bash
# env: GITHUB_TOKEN already set
login="octocat"
gh api graphql -f query='
query($login:String!) {
  user(login:$login) {
    login
    followers { totalCount }
    repositories(privacy: PUBLIC, isFork: false, first: 50, orderBy:{field:STARGAZERS, direction:DESC}) {
      totalCount
      nodes { name stargazerCount primaryLanguage { name } }
    }
    pullRequests(states: MERGED, first: 50, orderBy:{field:UPDATED_AT, direction:DESC}) {
      nodes {
        mergedAt
        repository { nameWithOwner }
        commits { totalCount }
        reviews { totalCount }
      }
    }
    contributionsCollection(from:"2024-10-01T00:00:00Z") {
      totalCommitContributions
      pullRequestReviewContributions(first: 100) { totalCount }
    }
  }
}' -f login=$login
```

Why GraphQL? You can fetch nested data (PRs → reviews → repo) and handle pagination efficiently. ([GitHub Docs][5])

> Tip: If you need true cross-GitHub velocity at scale (thousands of users), join with **GH Archive** in BigQuery for event-level stats (stars, PRs, reviews, issues) over time windows. Use it to pre-filter, then hydrate a shortlist with `gh`. ([davelester.github.io][6])

## 3) Scoring recipe (simple, defensible)

Use a bounded 100-point rubric; weights are adjustable per role.

**Activity & quality (60 pts)**

* Merged PRs in last 6–12 months, weighted by repo popularity (cap at 25).
* Review signal (reviews done + approvals received; cap 15).
* Issue responsiveness/close-rate on their own repos (cap 10).
* CI pass on their PRs (if accessible via Checks API; cap 10).

**Reputation (25 pts)**

* Followers (log-scaled) + sustained stars on owned repos (cap 10).
* Maintainer roles in notable repos (cap 10).
* Package ecosystem impact (downloads/dependents if npm/pip; cap 5).

**Fit & availability (15 pts)**

* Language/domain match (cap 10).
* Hiring signal (“Available for hire”/sponsors open/explicit freelance note; cap 5). ([GitHub][7])

> Implementation detail
>
> * You can compute this in one Claude “tool-use” pass that:
>
>   1. calls `gh` shell commands,
>   2. merges JSON,
>   3. applies the scoring function,
>   4. writes `/tmp/leaderboard.csv`, and
>   5. posts a summary.

## 4) Automate with Claude Agent SDK

A minimalist TypeScript agent that shells out to `gh`, scores, and publishes a Markdown leaderboard:

```ts
// ts-node script
import { Agent } from "@anthropic-ai/claude-agent-sdk";
import { execFileSync } from "node:child_process";
import fs from "node:fs";

const agent = new Agent({ name: "GH Talent Scout" });

function ghJson(args: string[]) {
  const out = execFileSync("gh", args, { encoding: "utf8" });
  return JSON.parse(out);
}

agent.tool("searchCandidates", async ({ language, location }) => {
  const q = `type:user language:${language} location:"${location}" followers:>50 repos:>15`;
  return ghJson(["search", "users", q, "--sort", "followers", "--order", "desc", "--limit", "200",
                 "--json", "login,name,location,followers"]);
});

agent.tool("hydrateAndScore", async ({ logins }) => {
  // loop logins, call `gh api graphql` per login, compute 100-pt score, return array
  // (omit for brevity)
  return [];
});

agent.task("buildLeaderboard", async () => {
  const seed = await agent.runTool("searchCandidates", { language: "TypeScript", location: "Eastern Europe" });
  const top = await agent.runTool("hydrateAndScore", { logins: seed.map((u:any) => u.login) });
  top.sort((a:any,b:any)=>b.score-a.score);
  const md = `| Rank | Login | Score |\n|---|---|---|\n` + top.slice(0,50).map((r:any,i:number)=>`| ${i+1} | ${r.login} | ${r.score} |`).join("\n");
  fs.writeFileSync("leaderboard.md", md);
  return { path: "leaderboard.md" };
});

agent.run(); // schedule via cron/Action
```

SDK overview & capabilities. ([Claude Docs][3])

---

# Practical notes & gotchas

* **Rate limits**: authenticated GraphQL gives you generous limits; batch queries and use pagination. (The `gh api graphql` docs show pagination patterns.) ([The GitHub Blog][2])
* **Signal noise**: stars/commits can be skewed; keep them as partial inputs, not the decision. Cross-check with recent **merged PRs** and **reviews**.
* **Availability**: GitHub exposes a user’s hiring status (UI + API field historically surfaced as “hireable” / similar). Use it as a **soft** signal, not a gate. ([GitHub][7])
* **Scaling up**: Pre-rank with **OSS Insight** or **GH Archive** (fast SQL over all GitHub events), then hydrate finalists with GraphQL to compute your custom score. ([ossinsight.io][8])
* **Where to publish**: Post a Markdown **Gist**, Slack message, or Notion page; both `gh gist` and GitHub Actions CRON can automate daily runs. (CLI manual.) ([GitHub CLI][9])

---

## Does GitHub provide this out of the box?

* **Search helps a lot** (users, repos, issues; sorting and qualifiers), but **there’s no built-in freelancer leaderboard**. You’re assembling it from public signals. ([GitHub CLI][1])

---

If you want, I can draft:

1. a ready-to-run **GraphQL query** that fetches exactly the fields for the 100-pt rubric, and
2. a tiny **GitHub Action** that runs the agent nightly and pushes `leaderboard.md` to a repo.

[1]: https://cli.github.com/manual/gh_search_repos?utm_source=chatgpt.com "GitHub CLI | Take GitHub to the command line"
[2]: https://github.blog/developer-skills/github/exploring-github-cli-how-to-interact-with-githubs-graphql-api-endpoint/?utm_source=chatgpt.com "Exploring GitHub CLI: How to interact with GitHub's GraphQL API ..."
[3]: https://anthropic.mintlify.app/en/docs/claude-code/sdk/sdk-overview?utm_source=chatgpt.com "Agent SDK overview - Claude Docs - anthropic.mintlify.app"
[4]: https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels?utm_source=chatgpt.com "Managing labels - GitHub Docs"
[5]: https://docs.github.com/en/graphql?utm_source=chatgpt.com "GitHub GraphQL API documentation"
[6]: https://davelester.github.io/gharchive-bigquery-examples/?utm_source=chatgpt.com "Analyzing GitHub Data with BigQuery Using GH Archive"
[7]: https://github.com/github/docs/blob/main/content/search-github/searching-on-github/searching-users.md?utm_source=chatgpt.com "docs/content/search-github/searching-on-github/searching-users.md at ..."
[8]: https://ossinsight.io/?utm_source=chatgpt.com "OSS Insight"
[9]: https://cli.github.com/manual/index?utm_source=chatgpt.com "GitHub CLI manual"


I don't need this to be Boston specific -- I just need amazing builders (can be any language). I need these guys to be cutting edge too (so they have worked on tech released in the last 1 month) .. So give me two things: 1) A clear instructions I can run using Claude Code (CLI) .. and 2) the spec to automate it using Claude agent SDK .. so these would be two separate canvas documents. Think hard. 

Perfect—made you two separate canvas docs:

1. **Claude Code Runbook — Global “Cutting-Edge” GitHub Builder Leaderboard (Last 30 Days)**
2. **Claude Agent SDK Spec — Automated “Cutting-Edge” GitHub Builder Leaderboard**

They’re ready to run: the first is a paste-and-go CLI workflow; the second is a productionizable agent with tools, a scoring rubric, and a GitHub Action.

Quick context / why this works (with sources):

* **`gh search`** supports repo/user discovery with qualifiers like `created:`, `pushed:`, `stars:`, sorting, and JSON output.
* You can check **recent releases** via the GitHub **Releases API** (used in the runbook to identify “newly released” tech).
* **GraphQL API** lets you pull nested signals in one shot (PRs, reviews, followers, repositories) and includes user hiring/availability fields used as soft signals.
* If you want to scale pre-filtering to thousands of devs, **GH Archive** on BigQuery is ideal for fast event-level queries (stars, PRs, reviews).
* “Help wanted” is a common label pattern for open collaboration; it’s not global, but it’s a good optional source of active contributors.
* GitHub **Sponsors GraphQL** exists for soft “indie builder” signals (we only use counts—no sensitive details).

