# Contributing to Agentic AI Builders Leaderboard

Thank you for your interest in contributing! This leaderboard is an open-source project to celebrate and discover active builders in the agentic AI space.

## 🎯 Ways to Contribute

### 1. Report Issues

Found a bug or have a suggestion? [Open an issue](https://github.com/adorosario/agentic-ai-builders-leaderboard/issues/new) with:

- **Bug Reports**: Steps to reproduce, expected vs actual behavior
- **Feature Requests**: Clear description of the enhancement
- **Scoring Improvements**: Suggest better signals or weights

### 2. Improve the Scoring Algorithm

The current rubric has room for improvement! Consider:

**New Signals to Add:**
- CI/CD pass rate from GitHub Checks API
- Issue response time (maintainer engagement)
- Documentation contributions
- Multi-language polyglot bonus
- Domain expertise clustering (RAG agents, tool-calling, etc.)

**Adjustments:**
- Tune scoring weights in `scripts/score.py`
- Add domain-specific filters (e.g., Python-only leaderboard)
- Better bot detection

**How to contribute:**
1. Fork the repository
2. Modify `scripts/score.py` or `METHODOLOGY.md`
3. Test on sample data
4. Submit a PR with before/after examples

### 3. Optimize Performance

Current bottlenecks:
- Profile hydration takes ~10 minutes
- API rate limits slow down large runs
- No caching of hydrated profiles

**Ideas:**
- Implement async/await for parallel API calls
- Cache profiles in Redis/SQLite
- Use GitHub Archive (BigQuery) for initial filtering
- Batch GraphQL queries more efficiently

### 4. Add Visualizations

The leaderboard would benefit from:
- Trend charts (how rankings change over time)
- Category breakdowns (by company, language, location)
- Network graphs (contributor overlap across repos)
- Interactive dashboard (Streamlit, Plotly Dash)

### 5. Improve Documentation

Help make the project more accessible:
- Better installation instructions for Windows
- Video walkthrough of the workflow
- FAQ section
- Troubleshooting guide
- Translate to other languages

### 6. Domain-Specific Leaderboards

Create variants for:
- **Language-specific**: Python AI builders, TypeScript AI devs
- **Framework-specific**: LangChain experts, AutoGen contributors
- **Company-specific**: Builders at AI startups vs. FAANG
- **Geographic**: Top builders by region/country

---

## 🛠️ Development Setup

### Prerequisites

```bash
# Install tools
brew install gh jq python3  # macOS
sudo apt install gh jq python3  # Linux

# Authenticate
gh auth login
```

### Running Locally

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/agentic-ai-builders-leaderboard.git
cd agentic-ai-builders-leaderboard

# Run the workflow
./scripts/run_leaderboard.sh

# Test individual components
./scripts/extract_contributors_rest.sh
./scripts/hydrate_profiles.sh
python3 scripts/score.py
python3 scripts/export.py
```

### Code Style

- **Bash scripts**: Use `shellcheck` for linting
- **Python**: Follow PEP 8, keep functions focused
- **Documentation**: Clear comments for complex logic

---

## 📋 Pull Request Process

1. **Fork & Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Add tests if applicable
   - Update documentation (`README.md`, `METHODOLOGY.md`)
   - Keep commits focused and atomic

3. **Test Locally**
   ```bash
   # Run full workflow
   ./scripts/run_leaderboard.sh

   # Verify outputs
   cat leaderboard.md
   ```

4. **Submit PR**
   - Clear title describing the change
   - Link to related issue (if any)
   - Include before/after examples for scoring changes

5. **Code Review**
   - Address feedback promptly
   - Maintainers will review within 3-5 days

---

## 🚫 What We Won't Accept

- **Gaming the system**: PRs designed to artificially boost specific users
- **Spam**: Low-effort changes just to get commits
- **Closed data**: Solutions requiring proprietary APIs or paid services
- **Breaking changes**: Must maintain backward compatibility

---

## 📊 Scoring Changes Require Evidence

If you propose changes to the scoring algorithm, include:

1. **Rationale**: Why this signal matters
2. **Data**: Sample of 10-20 users showing impact
3. **Weights**: Justification for point values
4. **Trade-offs**: What biases does this introduce?

Example:
```
## Add CI Pass Rate (10 points)

**Rationale:** Measures code quality and testing discipline

**Sample Data:**
| User | CI Pass Rate | Current Score | New Score |
|---|---:|---:|---:|
| alice | 95% | 65 | 75 (+10) |
| bob | 60% | 62 | 68 (+6) |

**Weights:** 10 pts for >90%, 5 pts for >70%, 0 otherwise

**Trade-offs:** Biases toward projects with mature CI; penalizes experimental repos
```

---

## 🤝 Community Standards

- **Be respectful**: This celebrates builders, not criticizes
- **No doxxing**: Don't add personal info beyond public GitHub profiles
- **Transparency**: All algorithms must be open and auditable
- **Inclusivity**: Welcome contributors of all skill levels

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## 🙋 Questions?

- **GitHub Discussions**: For general questions
- **Issues**: For bug reports and features
- **Email**: (coming soon)

---

**Happy contributing!** 🚀

Together we can build the most comprehensive map of agentic AI builders.
