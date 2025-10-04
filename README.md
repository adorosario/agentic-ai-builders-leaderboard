# 🤖 Agentic AI Builders Leaderboard

> **Discovering the cutting-edge builders** actively contributing to AI agent technology in the last 30 days.

[![Update Leaderboard](https://github.com/adorosario/agentic-ai-builders-leaderboard/actions/workflows/update-leaderboard.yml/badge.svg)](https://github.com/adorosario/agentic-ai-builders-leaderboard/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🎯 What is This?

This repository automatically generates a **ranked leaderboard of developers** who are actively contributing to **agentic AI technology**—frameworks, tools, and projects focused on AI agents, LLM orchestration, and autonomous systems.

Unlike traditional GitHub rankings based on total stars or followers, this leaderboard focuses on **recent, meaningful contributions** to cutting-edge AI agent projects like:

- 🦜 **LangChain / LangGraph** - Agent orchestration
- 🤖 **AutoGen / CrewAI** - Multi-agent systems
- 🧠 **Claude Agent SDK** - Anthropic's agent framework
- 🔧 **Composio / Arcade AI** - Agent tooling
- 📊 **Langfuse / Helicone** - LLM observability
- 🌐 **Browser Use / OpenHands** - Web agents
- And 200+ more agentic AI repositories

## 🏆 Top 10 Builders (Last 30 Days)

| Rank | Developer | Score | Company | Merged PRs | Reviews |
|---:|:---|---:|:---|---:|---:|
| 1 | [evantahler](https://github.com/evantahler) | 68 | Arcade AI | 29 | 78 |
| 2 | [xingyaoww](https://github.com/xingyaoww) | 68 | All Hands AI | 50 | 115 |
| 3 | [Soulter](https://github.com/Soulter) | 66 | AstrBot | 24 | 55 |
| 4 | [connortbot](https://github.com/connortbot) | 65 | UWaterloo | 50 | 117 |
| 5 | [axiomofjoy](https://github.com/axiomofjoy) | 63 | - | 23 | 133 |
| 6 | [holtskinner](https://github.com/holtskinner) | 63 | Google | 46 | 91 |
| 7 | [juliettech13](https://github.com/juliettech13) | 63 | Helicone | 23 | 78 |
| 8 | [rbren](https://github.com/rbren) | 63 | Fairwinds | 50 | 50 |
| 9 | [Sushmithamallesh](https://github.com/Sushmithamallesh) | 63 | - | 23 | 48 |
| 10 | [krrishdholakia](https://github.com/krrishdholakia) | 62 | - | 31 | 38 |

**[📊 View Full Leaderboard (Top 50)](./leaderboard.md)** | **[📈 Download CSV](./leaderboard.csv)**

---

## 🔍 Methodology

The leaderboard uses a **100-point scoring rubric** that evaluates:

### Activity & Quality (60 points)
- **Merged PRs** (25 pts): Recent contributions to agentic AI projects
- **Code Reviews** (15 pts): Helping maintain code quality
- **CI Pass Rate** (10 pts): Future enhancement
- **Issue Responsiveness** (10 pts): Future enhancement

### Reputation (25 points)
- **Followers** (10 pts): Log-scaled GitHub following
- **Repository Stars** (10 pts): Impact of personal projects
- **Maintainer Status** (5 pts): Future enhancement

### Availability (15 points)
- **Hireable Status** (5 pts): Open to opportunities
- **Bio Keywords** (3 pts): Signals like "freelance", "available"
- **Stack Fit** (10 pts): Neutral for global search

**[📖 Read Full Methodology](./METHODOLOGY.md)**

---

## 🚀 Quick Start

### Prerequisites

```bash
# Install dependencies
brew install gh jq python3  # macOS
# OR
sudo apt install gh jq python3  # Linux

# Authenticate with GitHub
gh auth login
```

### Run the Leaderboard

```bash
# Clone the repository
git clone https://github.com/adorosario/agentic-ai-builders-leaderboard.git
cd agentic-ai-builders-leaderboard

# Run the complete workflow
./scripts/run_leaderboard.sh

# View results
cat leaderboard.md
```

The script will:
1. 🔎 Search for ~200 agentic AI repos updated in last 30 days
2. 👥 Extract ~300 unique contributors with merged PRs
3. 💎 Hydrate profiles with activity, followers, reviews
4. 🎯 Score using 100-point rubric
5. 📊 Export CSV + Markdown leaderboards

---

## 📂 Repository Structure

```
.
├── README.md                          # This file
├── METHODOLOGY.md                     # Detailed scoring explanation
├── CONTRIBUTING.md                    # How to contribute
├── CLAUDE.md                          # AI assistant guidance
├── leaderboard.md                     # Top 50 formatted table
├── leaderboard.csv                    # Full 200 entries
├── leaderboard.jsonl                  # Raw scored data
├── scripts/
│   ├── run_leaderboard.sh            # Main orchestrator
│   ├── extract_contributors_rest.sh  # Get PR authors via REST API
│   ├── hydrate_profiles.sh           # Fetch user profiles via GraphQL
│   ├── score.py                      # Apply 100-point rubric
│   ├── export.py                     # Generate CSV/Markdown
│   └── README.md                     # Script documentation
├── docs/                              # Original documentation
└── .github/workflows/
    └── update-leaderboard.yml        # Daily automation
```

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

- 🐛 **Report bugs** or suggest improvements via [Issues](https://github.com/adorosario/agentic-ai-builders-leaderboard/issues)
- 🎨 **Improve scoring** algorithm or add new signals
- 📊 **Add visualizations** or analytics
- 🔧 **Optimize performance** for larger datasets
- 📝 **Improve documentation**

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed guidelines.

---

## 🔄 Automation

The leaderboard **updates automatically** every day at 03:00 UTC via GitHub Actions.

You can also trigger a manual update:
```bash
gh workflow run update-leaderboard.yml
```

---

## 📊 Use Cases

- **🏢 Recruiting**: Find active builders in the AI agent space
- **🤝 Collaboration**: Discover potential open-source collaborators
- **📈 Trends**: Track who's building what in agentic AI
- **🎓 Learning**: Study contributions of top builders
- **🏆 Recognition**: Celebrate cutting-edge contributors

---

## 📜 License

MIT License - see [LICENSE](./LICENSE) for details.

---

## 🙏 Acknowledgments

- Built with [GitHub CLI](https://cli.github.com/)
- Powered by GitHub's GraphQL & REST APIs
- Inspired by the agentic AI community

---

**Last Updated**: Auto-generated daily | **Contributors Tracked**: 272 | **Repos Analyzed**: 201

*Made with Claude Code* 🤖
