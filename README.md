# autoloop

Autonomous evolution loop for [theo-code](https://github.com/usetheodev/theo-code), an AI coding assistant built in Rust. Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) pattern: an AI agent runs overnight making incremental improvements, evaluating each change against an immutable harness, and keeping or discarding based on a composite score.

## How it works

An AI agent (Claude Code) reads `theo-program.md`, makes a small code change to the theo-code repo, runs `theo-evaluate.sh`, and decides: score went up? Keep. Score went down? Revert. Repeat forever.

The system evaluates a **Rust workspace with 11 library crates + 2 app binaries** against a **dual-layer score** covering both workspace hygiene and harness engineering maturity.

```
LOOP FOREVER:
  1. Pick a feature from .theo/feature_list.json
  2. Make a focused code change in theo-code
  3. Capture BEFORE_SHA, stage explicit paths, commit
  4. bash theo-evaluate.sh → score = (L1 + L2) / 2
  5. score improved? → keep : git reset --hard "$BEFORE_SHA"
  6. Log to results.tsv
  7. Check budget (max 200 experiments per session)
```

## Prerequisites

- **Rust toolchain** (rustc + cargo) — install via [rustup](https://rustup.rs/)
- **Python 3.6+** — used for score computation inside the eval harness
- **Git** — for experiment versioning
- **theo-code repo** — cloned locally with `.theo/feature_list.json` present

## Files that matter

| File | Purpose | Who edits |
|------|---------|-----------|
| `theo-evaluate.sh` | Immutable evaluation harness. Runs cargo build + test + clippy, outputs score 0-100. | **Nobody** (ground truth, chmod 444) |
| `theo-evaluate.sha256` | SHA-256 checksum of eval harness. Verified on every eval run. | **theo-init.sh** (generated automatically) |
| `theo-program.md` | Agent instructions. Setup, experiment loop, 5-phase strategy, failure taxonomy, guardrails. | **Human** (iterate on strategy) |
| `theo-architecture.md` | Complete architecture map of theo-code. Components, flows, state machines, known issues. | **Human** (update when architecture changes) |
| `theo-init.sh` | One-time setup. Verifies toolchain, warms cache, runs baseline, generates SHA-256. | **Human** |
| `guardrails.md` | 15 guardrails in 3 layers: immutable limits (with enforcement), circuit breakers, observability. | **Human** |
| `metrics.md` | Canonical source for all metrics: product (score), process (velocity, success rate), harness (coverage). | **Human** |
| `flows.md` | 5 operational flows: bootstrap, experiment loop, phase transition, failure recovery, crate order. | **Human** |
| `roadmap.md` | Evidence-based roadmap: 6 phases from STABILIZE to MAINTAIN. | **Human** |
| `CHANGELOG.md` | All notable changes to autoloop. | **Human** |
| `.theo/feature_list.json` | 20 prioritized features across Layer 1 and Layer 2. Lives in theo-code repo. | **Agent** (updates status to done) |
| `results.tsv` | Permanent log of all experiments (17 columns). Untracked by git. | **Agent** |
| `progress.md` | Session continuity file. Where did the last session stop? Untracked by git. | **Agent** |
| `experiment_traces.jsonl` | Structured trace per experiment (JSONL). Untracked by git. | **Agent** |

## Dual-layer score

**Score = (L1 + L2) / 2** — higher is better, 0-100. See `metrics.md` for the complete formula.

**Layer 1 — Workspace Hygiene** (100 pts):
- Crates that compile (40 pts)
- Test pass rate (40 pts)
- Total test count (10 pts, capped at 2500)
- Cargo warning penalty (10 pts)

**Layer 2 — Harness Maturity** (100 pts):
- Clippy cleanliness (20 pts, cap: 600)
- Unwrap density in production code (20 pts, cap: 1500)
- Structural test count (15 pts, capped at 30)
- Documentation artifacts presence (15 pts, 5 artifacts × 3 pts)
- Dead code hygiene (15 pts)
- Boundary test count (15 pts, capped at 15)

## 5-phase strategy

The agent progresses automatically:

1. **STABILIZE** (L1 < 95): Fix compilation, warnings, failing tests
2. **SCAFFOLD** (doc_artifacts < 5/5): Create clippy.toml, AGENTS.md, QUALITY_RULES.md, QUALITY_SCORE.md, structural_hygiene.rs
3. **FORTIFY** (L2 < 60): Clippy fixes, unwrap removal, expand structural + boundary tests
4. **POLISH** (score improving): Deeper improvements, test coverage, remaining features
5. **MAINTAIN** (continuous): Garbage collection, dashboard updates, drift detection

## Quick start

```bash
# 1. Run init (verifies toolchain, warms cache, shows baseline, generates SHA-256)
bash theo-init.sh /path/to/theo-code

# 2. Create experiment branch in theo-code
cd /path/to/theo-code
git switch -c autoresearch/apr16

# 3. Ensure .theo/feature_list.json exists in theo-code
#    (theo-init.sh will warn if missing)

# 4. Start Claude Code and point it to the instructions
# Prompt: "Read /path/to/autoloop/theo-program.md and kick off a new experiment"
```

## Operator guide — reading overnight results

After an overnight run, check these files in the theo-code repo:

### progress.md
Quick summary of what happened:
```bash
cat progress.md
# Shows: current phase, score, experiment count, recent keeps/discards, next steps
```

### results.tsv
Full experiment log (17 tab-separated columns):
```bash
# Total experiments
wc -l results.tsv

# Success rate
awk -F'\t' 'NR>1{total++; if($16=="keep") keeps++} END{printf "%.0f%% (%d/%d)\n", keeps/total*100, keeps, total}' results.tsv

# Score progression (keeps only)
awk -F'\t' 'NR>1 && $16=="keep" {print $2}' results.tsv
```

**Column reference**: commit, score, l1_score, l2_score, compile_crates, tests_passed, tests_failed, test_count, cargo_warnings, clippy_warnings, unwrap_count, structural_tests, boundary_tests, doc_artifacts, dead_code_attrs, status, description

### experiment_traces.jsonl
Structured JSON, one line per experiment:
```bash
# Last 5 experiments
tail -5 experiment_traces.jsonl | python3 -m json.tool

# Failure distribution
grep -o '"failure_reason":"[^"]*"' experiment_traces.jsonl | sort | uniq -c | sort -rn
```

## Recovery procedures

### Branch in unknown state after crash
```bash
# Check current score
bash /path/to/autoloop/theo-evaluate.sh /path/to/theo-code

# Find last known-good commit (last keep)
git log --oneline -20

# Verify harness integrity
sha256sum -c /path/to/autoloop/theo-evaluate.sha256
```

### Corrupt progress.md
Delete it and re-run init. The agent will create a fresh one from the baseline eval.

### Want to start fresh
```bash
git switch -c autoresearch/new-tag
rm -f results.tsv progress.md experiment_traces.jsonl
bash /path/to/autoloop/theo-init.sh /path/to/theo-code
```

## Design principles

- **Immutable harness**: `theo-evaluate.sh` is never modified during experiments. It is the ground truth. Protected by chmod 444 and SHA-256 verification.
- **Git as state machine**: Each experiment is one commit. Keep = branch advances. Discard = `git reset --hard "$BEFORE_SHA"`.
- **Monotonic score**: Every improvement always increases the score. No tradeoffs to manage.
- **Leaf-first changes**: Modify leaf crates (fewest dependents) before core crates to minimize rebuild cascading.
- **Simplicity criterion**: A small improvement that adds ugly complexity is not worth keeping.
- **Explicit staging**: Only allowed paths are staged (no `git add -A`), preventing accidental credential commits.
- **Budget enforcement**: Max 200 experiments per session prevents unbounded resource consumption.

## Background

This approach combines:
- [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — autonomous modify-evaluate-keep/discard loop
- [Anthropic's effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — feature lists, incremental progress, session continuity
- [Harness engineering](https://martinfowler.com/articles/harness-engineering.html) (Böckeler/Fowler) — feedforward guides + feedback sensors
- [OpenAI's harness engineering](https://openai.com/index/harness-engineering/) — repo knowledge as system of record, garbage collection
- [VeRO](https://arxiv.org/abs/2602.22480) (Scale AI) — versioned evaluation harness for agent optimization

## License

MIT
