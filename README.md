# autoloop

Autonomous evolution loop for [theo-code](https://github.com/usetheodev/theo-code), an AI coding assistant built in Rust. Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) pattern: an AI agent runs overnight making incremental improvements, evaluating each change against an immutable harness, and keeping or discarding based on a composite score.

## How it works

An AI agent (Claude Code) reads `theo-program.md`, makes a small code change to the theo-code repo, runs `theo-evaluate.sh`, and decides: score went up? Keep. Score went down? Revert. Repeat forever.

The system evaluates a **Rust workspace with 11 crates** against a **dual-layer score** covering both workspace hygiene and harness engineering maturity.

```
LOOP FOREVER:
  1. Pick a feature from .theo/feature_list.json
  2. Make a focused code change in theo-code
  3. git commit
  4. bash theo-evaluate.sh → score = (L1 + L2) / 2
  5. score improved? → keep : git reset --hard HEAD~1
  6. Log to results.tsv
```

## Files that matter

| File | Purpose | Who edits |
|------|---------|-----------|
| `theo-evaluate.sh` | Immutable evaluation harness. Runs cargo build + test + clippy, outputs score 0-100. | **Nobody** (ground truth) |
| `theo-program.md` | Agent instructions. Setup, experiment loop, 4-phase strategy, failure taxonomy. | **Human** (iterate on strategy) |
| `theo-architecture.md` | Complete architecture map of theo-code. Components, flows, state machines, known issues. | **Human** (update when architecture changes) |
| `theo-init.sh` | One-time setup. Verifies toolchain, warms cache, runs baseline. | **Human** |
| `.theo/feature_list.json` | 20 prioritized features across Layer 1 and Layer 2. | **Agent** (updates status to done) |
| `results.tsv` | Permanent log of all experiments. Untracked by git. | **Agent** |

## Dual-layer score

**Score = (L1 + L2) / 2** — higher is better, 0-100.

**Layer 1 — Workspace Hygiene** (100 pts):
- Crates that compile (40 pts)
- Test pass rate (40 pts)
- Total test count (10 pts, capped at 2500)
- Cargo warning penalty (10 pts)

**Layer 2 — Harness Maturity** (100 pts):
- Clippy cleanliness (20 pts)
- Unwrap density in production code (20 pts)
- Structural test count (15 pts, capped at 30)
- Documentation artifacts presence (15 pts, 5 artifacts x 3 pts)
- Dead code hygiene (15 pts)
- Boundary test count (15 pts, capped at 15)

## 4-phase strategy

The agent progresses automatically:

1. **STABILIZE** (L1 < 95): Fix compilation, warnings, failing tests
2. **SCAFFOLD** (doc_artifacts < 5/5): Create clippy.toml, AGENTS.md, QUALITY_RULES.md, QUALITY_SCORE.md, structural_hygiene.rs
3. **FORTIFY** (L2 < 60): Clippy fixes, unwrap removal, expand structural + boundary tests
4. **POLISH** (plateau): Deeper improvements, test coverage, remaining features

## Quick start

```bash
# 1. Run init (verifies toolchain, warms cache, shows baseline)
bash theo-init.sh /path/to/theo-code

# 2. Create experiment branch in theo-code
cd /path/to/theo-code
git checkout -b autoresearch/apr16

# 3. Start Claude Code and point it to the instructions
# Prompt: "Read /path/to/autoloop/theo-program.md and kick off a new experiment"
```

## Design principles

- **Immutable harness**: `theo-evaluate.sh` is never modified during experiments. It is the ground truth.
- **Git as state machine**: Each experiment is one commit. Keep = branch advances. Discard = `git reset --hard HEAD~1`.
- **Monotonic score**: Every improvement always increases the score. No tradeoffs to manage.
- **Leaf-first changes**: Modify leaf crates before core crates to minimize rebuild cascading.
- **Simplicity criterion**: A small improvement that adds ugly complexity is not worth keeping.

## Background

This approach combines:
- [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — autonomous modify-evaluate-keep/discard loop
- [Anthropic's effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — feature lists, incremental progress, session continuity
- [Harness engineering](https://martinfowler.com/articles/harness-engineering.html) (Böckeler/Fowler) — feedforward guides + feedback sensors
- [OpenAI's harness engineering](https://openai.com/index/harness-engineering/) — repo knowledge as system of record, garbage collection
- [VeRO](https://arxiv.org/abs/2602.22480) (Scale AI) — versioned evaluation harness for agent optimization

## License

MIT
