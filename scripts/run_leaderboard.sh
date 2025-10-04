#!/bin/bash
set -e

echo "🤖 Agentic AI Builders Leaderboard Generator"
echo "============================================="
echo ""

# Configuration
DAYS=30
MIN_STARS=20
SINCE=$(date -u -d "-${DAYS} days" +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -v-${DAYS}d +%Y-%m-%dT00:00:00Z)

echo "📅 Date Range: Last $DAYS days (since $SINCE)"
echo ""

# Step 1: Discover agentic AI repositories
echo "🔍 Step 1: Discovering agentic AI repositories..."
> agentic_seed.jsonl

gh search repos "agent AI pushed:>=$(echo $SINCE | cut -dT -f1) stars:>=$MIN_STARS" \
  --sort stars --order desc --limit 100 --json fullName,stargazersCount,language,updatedAt | \
  jq -c '.[]' > agentic_repos_1.jsonl

gh search repos "langchain pushed:>=$(echo $SINCE | cut -dT -f1) stars:>=$MIN_STARS" \
  --sort stars --order desc --limit 50 --json fullName,stargazersCount,language,updatedAt | \
  jq -c '.[]' > agentic_repos_2.jsonl

gh search repos "langgraph pushed:>=$(echo $SINCE | cut -dT -f1) stars:>=5" \
  --sort stars --order desc --limit 50 --json fullName,stargazersCount,language,updatedAt | \
  jq -c '.[]' > agentic_repos_3.jsonl

gh search repos "LLM agent pushed:>=$(echo $SINCE | cut -dT -f1) stars:>=$MIN_STARS" \
  --sort stars --order desc --limit 50 --json fullName,stargazersCount,language,updatedAt | \
  jq -c '.[]' > agentic_repos_4.jsonl

# Add specific high-signal repos
SPECIFIC_REPOS="anthropics/anthropic-sdk-typescript anthropics/anthropic-quickstarts langchain-ai/langgraph langchain-ai/langchain openai/openai-python langfuse/langfuse crewAIInc/crewAI"
for REPO in $SPECIFIC_REPOS; do
  gh api repos/$REPO --jq '{fullName: .full_name, stargazersCount: .stargazers_count, language: .language, updatedAt: .updated_at}' 2>/dev/null | \
    jq -c '.' >> agentic_repos_specific.jsonl
done

# Merge and deduplicate
cat agentic_repos_*.jsonl | jq -s 'unique_by(.fullName)' | jq -c '.[]' > agentic_seed.jsonl
REPO_COUNT=$(wc -l < agentic_seed.jsonl)
echo "   ✅ Found $REPO_COUNT unique agentic AI repositories"
echo ""

# Step 2: Extract contributors
echo "👥 Step 2: Extracting contributors from top 30 repos..."
./scripts/extract_contributors_rest.sh
CONTRIBUTOR_COUNT=$(jq -r .login candidates_raw.jsonl | sort -u | wc -l)
echo "   ✅ Found $CONTRIBUTOR_COUNT unique contributors"
echo ""

# Step 3: Hydrate profiles
echo "💎 Step 3: Hydrating contributor profiles (this may take a few minutes)..."
./scripts/hydrate_profiles.sh
PROFILE_COUNT=$(wc -l < hydrated.jsonl)
echo "   ✅ Hydrated $PROFILE_COUNT profiles"
echo ""

# Step 4: Score candidates
echo "🎯 Step 4: Scoring candidates with 100-point rubric..."
python3 ./scripts/score.py
echo ""

# Step 5: Export leaderboard
echo "📊 Step 5: Exporting leaderboard..."
python3 ./scripts/export.py
echo ""

echo "✅ Leaderboard generation complete!"
echo ""
echo "📁 Output files:"
echo "   - leaderboard.md    (Top 50 formatted table)"
echo "   - leaderboard.csv   (Full 200 entries)"
echo "   - leaderboard.jsonl (Raw scored data)"
echo ""
echo "🏆 Top 5 Builders:"
head -8 leaderboard.md | tail -5
